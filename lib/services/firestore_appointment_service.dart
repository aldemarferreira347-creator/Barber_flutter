import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment.dart';
import '../models/payment_record.dart';
import '../repositories/appointment_repository.dart';
import 'appointment_slot_id.dart';
import '../utils/shared_stream.dart';

// Nota: a diferencia de FirestoreBarbershopService (que sí conserva un
// método atado a Cloud Functions para cuando el proyecto suba a Blaze),
// aquí no queda ninguno — bookPaidAppointment/postponeAppointment/
// requestAppointmentRefund se migraron todos a Firestore directo, así que
// esta clase ya no depende de FirebaseFunctions.
class FirestoreAppointmentService implements AppointmentRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreAppointmentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection('appointmentSlots');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  @override
  Future<String> create(Appointment appointment) async {
    final doc = await _appointments.add(appointment.toMap());
    return doc.id;
  }

  @override
  Future<String> createPaid({
    required String barbershopId,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String clientName,
    required DateTime date,
    required String reference,
  }) async {
    final clientId = _auth.currentUser?.uid;
    if (clientId == null) throw Exception('Debes iniciar sesión.');

    // Antes esto lo hacía bookPaidAppointment (Admin SDK): bloquear el
    // horario con una transacción ANTES de cobrar, para que dos clientes
    // nunca puedan ganar el mismo horario (spec 6.2). Sin plan Blaze, la
    // app corre la misma transacción directo — ver firestore.rules para
    // las reglas que evitan que el cliente falsifique el precio o el pago.
    final serviceSnap = await _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('services')
        .doc(serviceId)
        .get();
    final serviceData = serviceSnap.data();
    if (!serviceSnap.exists ||
        serviceData == null ||
        serviceData['active'] != true) {
      throw Exception('Ese servicio ya no está disponible.');
    }
    final servicePrice = serviceData['price'];
    final durationMinutes = serviceData['durationMinutes'];
    final serviceName = serviceData['name'];

    final slotRef = _slots.doc(appointmentSlotId(barberId, date));
    final appointmentRef = _appointments.doc();
    final paymentRef = _payments.doc();

    // El pago Nequi (pendiente, con la referencia del comprobante) se crea
    // ANTES de intentar el bloqueo del horario: así, si la transacción falla
    // porque alguien más ya lo tomó, queda constancia del intento fallido
    // en vez de un pago fantasma. Queda pendiente hasta que el personal
    // verifique el dinero en su Nequi (confirmPayment).
    await paymentRef.set(
      PaymentRecord.newPendingMap(
        payerId: clientId,
        amount: servicePrice as num,
        category: PaymentCategory.appointment,
        relatedId: appointmentRef.id,
        description: 'Cita en barbershops/$barbershopId',
        reference: reference,
      ),
    );

    try {
      await _firestore.runTransaction((tx) async {
        final slotSnap = await tx.get(slotRef);
        if (slotSnap.exists) {
          throw Exception('Ese horario ya no está disponible.');
        }
        tx.set(slotRef, {
          'appointmentId': appointmentRef.id,
          'barberId': barberId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(appointmentRef, {
          'barbershopId': barbershopId,
          'barberId': barberId,
          'barberName': barberName,
          'clientId': clientId,
          'clientName': clientName,
          'serviceId': serviceId,
          'serviceName': serviceName,
          'servicePrice': servicePrice,
          'durationMinutes': durationMinutes,
          'date': Timestamp.fromDate(date),
          'status': 'pending',
          'paid': true,
          'paymentId': paymentRef.id,
          'rescheduleHistory': <Map<String, dynamic>>[],
          'forcedRatingPenalty': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      await paymentRef.update({
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }

    return appointmentRef.id;
  }

  /// Lee la cita y su pago pendiente; falla con un mensaje claro si ya no
  /// hay nada que verificar (otro miembro del personal ya lo resolvió).
  Future<
    ({Appointment appointment, DocumentReference<Map<String, dynamic>> payment})
  >
  _pendingPaidAppointment(String appointmentId) async {
    final snap = await _appointments.doc(appointmentId).get();
    final data = snap.data();
    if (!snap.exists || data == null) throw Exception('La cita no existe.');
    final appointment = Appointment.fromMap(snap.id, data);
    final paymentId = appointment.paymentId;
    if (!appointment.paid || paymentId == null) {
      throw Exception('Esta cita no tiene un pago por verificar.');
    }
    final paymentRef = _payments.doc(paymentId);
    final paymentSnap = await paymentRef.get();
    if (paymentSnap.data()?['status'] != PaymentIntentStatus.pending.value) {
      throw Exception('El pago de esta cita ya fue resuelto.');
    }
    return (appointment: appointment, payment: paymentRef);
  }

  Map<String, dynamic> _resolution(String status) => {
    'status': status,
    'resolvedAt': FieldValue.serverTimestamp(),
    'resolvedBy': _auth.currentUser?.uid,
  };

  @override
  Future<void> confirmPayment(String appointmentId) async {
    final pending = await _pendingPaidAppointment(appointmentId);
    // Una sola escritura: el pago queda verificado y la cita aceptada (las
    // reglas no dejan aceptar una cita pagada con el pago sin verificar).
    final batch = _firestore.batch();
    batch.update(
      pending.payment,
      _resolution(PaymentIntentStatus.approved.value),
    );
    batch.update(_appointments.doc(appointmentId), {
      'status': AppointmentStatus.accepted.value,
    });
    await batch.commit();
  }

  @override
  Future<void> rejectPayment(String appointmentId) async {
    final pending = await _pendingPaidAppointment(appointmentId);
    // El dinero no llegó: el pago se rechaza, la cita se cancela y el
    // horario vuelve a quedar libre — todo junto.
    final batch = _firestore.batch();
    batch.update(
      pending.payment,
      _resolution(PaymentIntentStatus.rejected.value),
    );
    batch.update(_appointments.doc(appointmentId), {
      'status': AppointmentStatus.cancelled.value,
    });
    batch.delete(
      _slots.doc(
        appointmentSlotId(
          pending.appointment.barberId,
          pending.appointment.date,
        ),
      ),
    );
    await batch.commit();
  }

  /// Citas que se escuchan por consulta: las más recientes (incluye las
  /// futuras). Evita descargar años de historial en cada apertura.
  static const _maxAppointments = 200;

  static List<Appointment> _toAscendingList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs
      .map((doc) => Appointment.fromMap(doc.id, doc.data()))
      .toList()
      .reversed
      .toList();

  @override
  Stream<Appointment?> watchOne(String appointmentId) {
    return _shared.of<Appointment?>('watchOne:$appointmentId', () {
      return _appointments.doc(appointmentId).snapshots().map((doc) {
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        return Appointment.fromMap(doc.id, data);
      });
    });
  }

  @override
  Stream<List<Appointment>> watchByClient(String clientId) {
    return _shared.of<List<Appointment>>('watchByClient:$clientId', () {
      return _appointments
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true)
          .limit(_maxAppointments)
          .snapshots()
          .map(_toAscendingList);
    });
  }

  @override
  Stream<List<Appointment>> watchByBarber(String barberId) {
    return _shared.of<List<Appointment>>('watchByBarber:$barberId', () {
      return _appointments
          .where('barberId', isEqualTo: barberId)
          .orderBy('date', descending: true)
          .limit(_maxAppointments)
          .snapshots()
          .map(_toAscendingList);
    });
  }

  @override
  Stream<List<Appointment>> watchByBarbershop(String barbershopId) {
    return _shared.of<List<Appointment>>('watchByBarbershop:$barbershopId', () {
      return _appointments
          .where('barbershopId', isEqualTo: barbershopId)
          .orderBy('date', descending: true)
          .limit(_maxAppointments)
          .snapshots()
          .map(_toAscendingList);
    });
  }

  @override
  Stream<List<Appointment>> watchByBarbershops(List<String> barbershopIds) {
    return _shared.of<List<Appointment>>(
      'watchByBarbershops:${(List.of(barbershopIds)..sort()).join(',')}',
      () {
        if (barbershopIds.isEmpty) return Stream.value(const <Appointment>[]);
        late StreamController<List<Appointment>> controller;
        final subscriptions = <StreamSubscription<List<Appointment>>>[];
        final latest = <String, List<Appointment>>{};

        void emit() {
          if (latest.length < barbershopIds.length) return;
          controller.add(
            [for (final list in latest.values) ...list]
              ..sort((a, b) => a.date.compareTo(b.date)),
          );
        }

        controller = StreamController<List<Appointment>>(
          onListen: () {
            for (final id in barbershopIds) {
              subscriptions.add(
                watchByBarbershop(id).listen((list) {
                  latest[id] = list;
                  emit();
                }, onError: controller.addError),
              );
            }
          },
          onCancel: () async {
            for (final sub in subscriptions) {
              await sub.cancel();
            }
          },
        );
        return controller.stream;
      },
    );
  }

  @override
  Future<void> setStatus(String id, AppointmentStatus status) {
    return _appointments.doc(id).update({'status': status.value});
  }

  @override
  Future<void> reschedule(String id, DateTime newDate) {
    return _appointments.doc(id).update({
      'date': Timestamp.fromDate(newDate),
      'status': AppointmentStatus.postponed.value,
    });
  }

  @override
  Future<void> postponePaid(String appointmentId, DateTime newDate) async {
    // Antes esto lo hacía postponeAppointment (Admin SDK): conserva el
    // pago, libera el horario viejo y reclama el nuevo con la misma
    // transacción atómica que la reserva original (spec 6.4).
    final appointmentRef = _appointments.doc(appointmentId);
    final appointmentSnap = await appointmentRef.get();
    final data = appointmentSnap.data();
    if (!appointmentSnap.exists || data == null) {
      throw Exception('La cita no existe.');
    }
    final appointment = Appointment.fromMap(appointmentSnap.id, data);

    final oldSlotRef = _slots.doc(
      appointmentSlotId(appointment.barberId, appointment.date),
    );
    final newSlotRef = _slots.doc(
      appointmentSlotId(appointment.barberId, newDate),
    );

    await _firestore.runTransaction((tx) async {
      final newSlotSnap = await tx.get(newSlotRef);
      if (newSlotSnap.exists) {
        throw Exception('Ese nuevo horario ya no está disponible.');
      }
      tx.delete(oldSlotRef);
      tx.set(newSlotRef, {
        'appointmentId': appointmentId,
        'barberId': appointment.barberId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(appointmentRef, {
        'date': Timestamp.fromDate(newDate),
        'status': AppointmentStatus.postponed.value,
        'rescheduleHistory': FieldValue.arrayUnion([
          {
            'from': Timestamp.fromDate(appointment.date),
            'to': Timestamp.fromDate(newDate),
          },
        ]),
      });
    });
  }

  @override
  Future<String> requestRefund({
    required String appointmentId,
    required String reason,
    String? purchaseId,
    List<int>? purchaseItemIndexes,
  }) async {
    final clientId = _auth.currentUser?.uid;
    if (clientId == null) throw Exception('Debes iniciar sesión.');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Debes indicar una justificación.');
    }

    final appointmentSnap = await _appointments.doc(appointmentId).get();
    final data = appointmentSnap.data();
    if (!appointmentSnap.exists || data == null) {
      throw Exception('La cita no existe.');
    }
    final barbershopId = data['barbershopId'] as String;

    final ref = await _firestore.collection('refundRequests').add({
      'appointmentId': appointmentId,
      'barbershopId': barbershopId,
      'clientId': clientId,
      'reason': trimmedReason,
      'purchaseId': purchaseId,
      'purchaseItemIndexes': purchaseItemIndexes,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'resolvedBy': null,
    });

    return ref.id;
  }
}
