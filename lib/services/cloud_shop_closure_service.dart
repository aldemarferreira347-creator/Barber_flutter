import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/shop_closure_repository.dart';
import 'appointment_slot_id.dart';

const _upcomingAppointmentStatuses = {'pending', 'accepted', 'postponed'};

// Nombre histórico (antes llamaba a closeShopForExternalEvent, Cloud
// Function) — sin plan Blaze escribe Firestore directo. Cada reserva
// pagada dentro del rango cerrado queda aplazada y marcada con el
// descuento obligatorio de calificación (spec 3.4), igual que antes.
//
// Limitación aceptada: el backend también avisaba (push/SMS/correo) a
// cada cliente afectado — sin servidor eso no es posible, igual que el
// resto de notificaciones automáticas de esta migración (ver
// cloud_barber_availability_service.dart). El cliente sigue viendo su cita
// aplazada la próxima vez que abre la app, solo que sin el aviso proactivo.
class CloudShopClosureService implements ShopClosureRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudShopClosureService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<int> closeForExternalEvent({
    required String barbershopId,
    required DateTime closedFrom,
    required DateTime closedUntil,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Debes indicar el motivo del cierre.');
    }
    if (!closedUntil.isAfter(closedFrom)) {
      throw Exception('closedUntil debe ser posterior a closedFrom.');
    }

    final closureRef = _firestore.collection('shopClosures').doc();
    await closureRef.set({
      'barbershopId': barbershopId,
      'closedFrom': Timestamp.fromDate(closedFrom),
      'closedUntil': Timestamp.fromDate(closedUntil),
      'reason': trimmedReason,
      'requestedBy': uid,
      'appointmentsAffected': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final appointmentsSnap = await _firestore
        .collection('appointments')
        .where('barbershopId', isEqualTo: barbershopId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(closedFrom))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(closedUntil))
        .get();

    var affected = 0;
    for (final doc in appointmentsSnap.docs) {
      final data = doc.data();
      if (data['paid'] != true ||
          !_upcomingAppointmentStatuses.contains(data['status'])) {
        continue;
      }

      final date = (data['date'] as Timestamp).toDate();
      final slotRef = _firestore
          .collection('appointmentSlots')
          .doc(appointmentSlotId(data['barberId'] as String, date));
      await Future.wait([
        doc.reference.update({
          'status': 'postponed',
          'forcedRatingPenalty': true,
        }),
        slotRef.delete(),
      ]);
      affected++;
    }

    await closureRef.update({'appointmentsAffected': affected});
    return affected;
  }
}
