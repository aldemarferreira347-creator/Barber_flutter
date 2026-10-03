import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/rating_repository.dart';
import '../utils/shared_stream.dart';

// Nombre histórico (antes llamaba a submitAppointmentRating, Cloud
// Function) — sin plan Blaze escribe Firestore directo. La validación de
// estrellas/penalización forzada y de que la cita sea propia, pagada y
// completada vive en firestore.rules, igual que en el backend.
class CloudRatingService implements RatingRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudRatingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _firestore.collection('ratings');

  @override
  Future<void> submitRating({
    required String appointmentId,
    required int barberStars,
    required int shopStars,
  }) async {
    final clientId = _auth.currentUser?.uid;
    if (clientId == null) throw Exception('Debes iniciar sesión.');
    if (barberStars < 1 || barberStars > 5 || shopStars < 1 || shopStars > 5) {
      throw Exception('Las estrellas deben ser un entero entre 1 y 5.');
    }

    final appointmentSnap = await _appointments.doc(appointmentId).get();
    final appointment = appointmentSnap.data();
    if (!appointmentSnap.exists || appointment == null) {
      throw Exception('La cita no existe.');
    }
    if (appointment['clientId'] != clientId) {
      throw Exception('Solo el cliente de esa cita puede calificarla.');
    }
    if (appointment['paid'] != true || appointment['status'] != 'completed') {
      throw Exception(
        'Solo se puede calificar una reserva pagada y completada.',
      );
    }

    final barbershopId = appointment['barbershopId'] as String;
    final barberId = appointment['barberId'] as String;
    // Cierre de tienda por evento externo (spec 3.4): descuento obligatorio
    // de 1 estrella en la calificación de la barbería (nunca en la del
    // barbero, que no tuvo responsabilidad en el cierre).
    final forcedPenalty = appointment['forcedRatingPenalty'] == true;
    final effectiveShopStars = forcedPenalty
        ? (shopStars > 1 ? shopStars - 1 : 1)
        : shopStars;

    await _ratings.doc(appointmentId).set({
      'appointmentId': appointmentId,
      'barbershopId': barbershopId,
      'barberId': barberId,
      'clientId': clientId,
      'barberStars': barberStars,
      'shopStars': shopStars,
      'effectiveShopStars': effectiveShopStars,
      'forcedRatingPenaltyApplied': forcedPenalty,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Antes esta suma la hacía submitAppointmentRating dentro de la MISMA
    // transacción atómica que crea el rating (Admin SDK), así el promedio
    // nunca podía desincronizarse del conteo real de calificaciones. Sin
    // Cloud Functions eso no es posible del lado del cliente: las reglas de
    // un documento no pueden ver las escrituras pendientes de otro
    // documento en su misma transacción, así que aquí van en dos pasos
    // separados y firestore.rules solo puede acotar el incremento a un
    // rango válido (1 a 5 por calificación), no atarlo criptográficamente a
    // esta calificación exacta. Si el segundo paso falla, el rating ya
    // quedó guardado pero el promedio no lo refleja todavía.
    await Future.wait([
      _firestore.collection('barbershops').doc(barbershopId).update({
        'ratingSum': FieldValue.increment(effectiveShopStars),
        'ratingCount': FieldValue.increment(1),
      }),
      _firestore.collection('users').doc(barberId).update({
        'ratingSum': FieldValue.increment(barberStars),
        'ratingCount': FieldValue.increment(1),
      }),
    ]);
  }

  @override
  Stream<Set<String>> watchRatedAppointmentIds(String clientId) {
    return _shared.of<Set<String>>('watchRatedAppointmentIds:$clientId', () {
      return _ratings
          .where('clientId', isEqualTo: clientId)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
    });
  }
}
