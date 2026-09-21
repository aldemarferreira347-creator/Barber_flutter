import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';
import 'appointment_slot_id.dart';

// Nota: a diferencia de FirestoreBarbershopService (que sí conserva un
// método atado a Cloud Functions para cuando el proyecto suba a Blaze),
// aquí no queda ninguno — bookPaidAppointment/postponeAppointment/
// requestAppointmentRefund se migraron todos a Firestore directo, así que
// esta clase ya no depende de FirebaseFunctions.
class FirestoreAppointmentService implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Duration _simulatedApprovalDelay;

  FirestoreAppointmentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    // Configurable solo para que los tests no esperen el delay real — igual
    // que el parámetro `delayMs` de SimulatedNequiGateway en el backend.
    Duration? simulatedApprovalDelay,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _simulatedApprovalDelay =
           simulatedApprovalDelay ?? const Duration(milliseconds: 1500);

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
    if (!serviceSnap.exists || serviceData == null || serviceData['active'] != true) {
      throw Exception('Ese servicio ya no está disponible.');
    }
    final servicePrice = serviceData['price'];
    final durationMinutes = serviceData['durationMinutes'];
    final serviceName = serviceData['name'];

    final slotRef = _slots.doc(appointmentSlotId(barberId, date));
    final appointmentRef = _appointments.doc();
    final paymentRef = _payments.doc();

    // El pago (simulado) se crea ANTES de intentar el bloqueo del horario:
    // así, si la transacción falla porque alguien más ya lo tomó, queda
    // constancia del intento fallido en vez de un pago fantasma.
    await paymentRef.set({
      'payerId': clientId,
      'amount': servicePrice,
      'category': 'appointment',
      'relatedId': appointmentRef.id,
      'description': 'Cita en barbershops/$barbershopId',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'refundedAmount': null,
    });

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

    await Future<void>.delayed(_simulatedApprovalDelay);
    await paymentRef.update({
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    return appointmentRef.id;
  }

  @override
  Stream<List<Appointment>> watchByClient(String clientId) {
    return _appointments
        .where('clientId', isEqualTo: clientId)
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Appointment>> watchByBarber(String barberId) {
    return _appointments
        .where('barberId', isEqualTo: barberId)
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Appointment>> watchByBarbershop(String barbershopId) {
    return _appointments
        .where('barbershopId', isEqualTo: barbershopId)
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList(),
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
    final newSlotRef = _slots.doc(appointmentSlotId(appointment.barberId, newDate));

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
