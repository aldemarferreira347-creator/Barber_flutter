import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment.dart';
import '../models/payment_record.dart';
import '../models/refund_request.dart';
import '../repositories/refund_request_repository.dart';
import 'appointment_slot_id.dart';
import '../utils/shared_stream.dart';

// El nombre quedó de cuando `resolve` llamaba a resolveAppointmentRefund
// (Cloud Function) — sin plan Blaze, ahora escribe Firestore directo (ver
// firestore.rules), pero se deja el nombre para no romper el resto de
// referencias a esta clase de nuevo tras el cambio anterior.
class CloudRefundRequestService implements RefundRequestRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudRefundRequestService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('refundRequests');

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection('appointmentSlots');

  /// Tope de cada lista: lo más reciente (las pantallas no paginan).
  static const _maxListItems = 100;

  @override
  Stream<List<RefundRequest>> watchByBarbershop(String barbershopId) {
    return _shared.of<List<RefundRequest>>(
      'watchByBarbershop:$barbershopId',
      () {
        return _requests
            .where('barbershopId', isEqualTo: barbershopId)
            .orderBy('createdAt', descending: true)
            .limit(_maxListItems)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => RefundRequest.fromMap(doc.id, doc.data()))
                  .toList(),
            );
      },
    );
  }

  @override
  Stream<List<RefundRequest>> watchByClient(String clientId) {
    return _shared.of<List<RefundRequest>>('watchByClient:$clientId', () {
      return _requests
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .limit(_maxListItems)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => RefundRequest.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });
  }

  @override
  Future<void> resolve(
    String requestId, {
    required bool approve,
    RefundMethod? method,
  }) async {
    // El dueño de la barbería (o el admin) aprueba/rechaza la solicitud
    // (spec 6.5). Todo el efecto de aprobar va en UNA escritura atómica: si
    // fallara a medias quedaría una cita cancelada con el pago sin resolver
    // (o al revés).
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');

    final requestRef = _requests.doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data();
    if (!requestSnap.exists || requestData == null) {
      throw Exception('La solicitud no existe.');
    }
    if (requestData['status'] != 'pending') {
      throw Exception('Esta solicitud ya fue resuelta.');
    }

    if (!approve) {
      await requestRef.update({
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': uid,
      });
      return;
    }

    final appointmentId = requestData['appointmentId'] as String;
    final appointmentRef = _appointments.doc(appointmentId);
    final appointmentSnap = await appointmentRef.get();
    final appointmentData = appointmentSnap.data();
    if (!appointmentSnap.exists || appointmentData == null) {
      throw Exception('La cita ya no existe.');
    }
    final appointment = Appointment.fromMap(
      appointmentSnap.id,
      appointmentData,
    );

    final batch = _firestore.batch();
    batch.update(appointmentRef, {'status': 'cancelled'});
    batch.update(requestRef, {
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': uid,
    });
    batch.delete(
      _slots.doc(appointmentSlotId(appointment.barberId, appointment.date)),
    );

    final paymentId = appointment.paymentId;
    if (paymentId != null) {
      final paymentRef = _payments.doc(paymentId);
      final status = (await paymentRef.get()).data()?['status'];
      if (status == PaymentIntentStatus.approved.value) {
        // El dinero ya se había confirmado: quien aprueba lo devuelve por
        // Nequi o en efectivo y deja registrado el medio.
        if (method == null) {
          throw Exception('Indica por qué medio devolviste el dinero.');
        }
        batch.update(paymentRef, {
          'status': PaymentIntentStatus.refunded.value,
          'refundedAmount': appointment.servicePrice,
          'refundMethod': method.value,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == PaymentIntentStatus.pending.value) {
        // Nunca se verificó el dinero: no hay nada que devolver, el pago se
        // da por no recibido.
        batch.update(paymentRef, {
          'status': PaymentIntentStatus.rejected.value,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': uid,
        });
      }
    }

    await batch.commit();
  }
}
