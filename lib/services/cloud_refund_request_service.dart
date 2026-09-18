import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/refund_request.dart';
import '../repositories/refund_request_repository.dart';

class CloudRefundRequestService implements RefundRequestRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CloudRefundRequestService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection('refundRequests');

  @override
  Stream<List<RefundRequest>> watchByBarbershop(String barbershopId) {
    return _requests
        .where('barbershopId', isEqualTo: barbershopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RefundRequest.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<RefundRequest>> watchByClient(String clientId) {
    return _requests
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RefundRequest.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<void> resolve(String requestId, {required bool approve}) {
    return _functions.httpsCallable('resolveAppointmentRefund').call<void>({
      'requestId': requestId,
      'approve': approve,
    });
  }
}
