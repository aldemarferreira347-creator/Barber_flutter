import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../repositories/rating_repository.dart';

class CloudRatingService implements RatingRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  CloudRatingService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> submitRating({
    required String appointmentId,
    required int barberStars,
    required int shopStars,
  }) {
    return _functions
        .httpsCallable('submitAppointmentRating')
        .call<Map<String, dynamic>>({
          'appointmentId': appointmentId,
          'barberStars': barberStars,
          'shopStars': shopStars,
        });
  }

  @override
  Stream<Set<String>> watchRatedAppointmentIds(String clientId) {
    return _firestore
        .collection('ratings')
        .where('clientId', isEqualTo: clientId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }
}
