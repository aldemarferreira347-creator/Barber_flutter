import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment.dart';
import '../models/refund_request.dart';
import '../repositories/refund_request_repository.dart';
import 'appointment_slot_id.dart';

// El nombre quedó de cuando `resolve` llamaba a resolveAppointmentRefund
// (Cloud Function) — sin plan Blaze, ahora escribe Firestore directo (ver
// firestore.rules), pero se deja el nombre para no romper el resto de
// referencias a esta clase de nuevo tras el cambio anterior.
class CloudRefundRequestService implements RefundRequestRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudRefundRequestService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('refundRequests');

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection('appointmentSlots');

  @override
  Stream<List<RefundRequest>> watchByBarbershop(String barbershopId) {
    return _requests
        .where('barbershopId', isEqualTo: barbershopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RefundRequest.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<RefundRequest>> watchByClient(String clientId) {
    return _requests
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RefundRequest.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> resolve(String requestId, {required bool approve}) async {
    // Antes esto lo hacía resolveAppointmentRefund (Admin SDK): el dueño
    // de la barbería (o el admin) aprueba/rechaza la solicitud (spec 6.5).
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');

    final requestRef = _requests.doc(requestId);
    final requestSnap = await requestRef.get();
    final requestData = requestSnap.data();
    if (!requestSnap.exists || requestData == null) {
      throw Exception('La solicitud no existe.');
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
    final appointment = Appointment.fromMap(appointmentSnap.id, appointmentData);

    final writes = <Future<void>>[
      appointmentRef.update({'status': 'cancelled'}),
      requestRef.update({
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': uid,
      }),
      _slots
          .doc(appointmentSlotId(appointment.barberId, appointment.date))
          .delete(),
    ];

    if (appointment.paymentId != null) {
      writes.add(
        _payments.doc(appointment.paymentId).update({
          'status': 'refunded',
          'refundedAmount': appointment.servicePrice,
          'resolvedAt': FieldValue.serverTimestamp(),
        }),
      );
    }

    // Nota: si la solicitud viene junto con una compra de producto
    // (purchaseId/purchaseItemIndexes), el reembolso de esos ítems queda
    // pendiente para cuando se migre el grupo de productos — hoy la UI
    // nunca envía esos campos (ver requestRefund en book/client
    // appointments), así que no hay caso real que cubrir todavía.

    await Future.wait(writes);
  }
}
