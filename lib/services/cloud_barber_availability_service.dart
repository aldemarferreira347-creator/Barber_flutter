import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/barber_availability_repository.dart';

const _minMinutes = 5;
const _maxMinutes = 240;

// Nombre histórico (antes llamaba a markBarberAway/markBarberReturned,
// Cloud Functions) — sin plan Blaze escribe Firestore directo; ver
// firestore.rules para el límite del estimado (5 a 240 minutos) y por qué
// solo el propio barbero puede tocar su awaySince/awayUntilEstimate.
//
// Limitación aceptada: el backend también avisaba (push/SMS/correo) al
// cliente con una cita en la próxima hora cuando el barbero volvía a
// tiempo, y aplazaba automáticamente las reservas pagadas de un barbero que
// no volvió dentro de su propio estimado (corrida periódica). Ninguna de
// las dos es posible sin un servidor — quedan pendientes, igual que el
// resto de notificaciones push con la app cerrada y la corrida diaria de
// mensualidades vencidas.
class CloudBarberAvailabilityService implements BarberAvailabilityRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudBarberAvailabilityService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<void> markAway(int estimatedMinutes) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');
    if (estimatedMinutes < _minMinutes || estimatedMinutes > _maxMinutes) {
      throw Exception('estimatedMinutes debe ser un entero entre $_minMinutes y $_maxMinutes.');
    }

    await _firestore.collection('users').doc(uid).update({
      'awaySince': FieldValue.serverTimestamp(),
      'awayUntilEstimate': Timestamp.fromDate(
        DateTime.now().add(Duration(minutes: estimatedMinutes)),
      ),
    });
  }

  @override
  Future<void> markReturned() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');

    await _firestore.collection('users').doc(uid).update({
      'awaySince': null,
      'awayUntilEstimate': null,
    });
  }
}
