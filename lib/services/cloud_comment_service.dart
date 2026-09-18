import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/comment.dart';
import '../repositories/comment_repository.dart';
import '../repositories/storage_repository.dart';

class CloudCommentService implements CommentRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final StorageRepository _storage;

  CloudCommentService({required this._storage, FirebaseFunctions? functions, FirebaseFirestore? firestore})
    : _functions = functions ?? FirebaseFunctions.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<CommentStatus> submitComment({required String appointmentId, required String text, String? photoUrl}) async {
    final result = await _functions.httpsCallable('submitAppointmentComment').call<Map<String, dynamic>>({
      'appointmentId': appointmentId,
      'text': text,
      'photoUrl': photoUrl,
    });
    return CommentStatusX.fromValue(result.data['status'] as String? ?? 'rejected');
  }

  @override
  Future<void> replyToComment({required String commentId, required String replyText}) {
    return _functions.httpsCallable('replyToComment').call<Map<String, dynamic>>({
      'commentId': commentId,
      'replyText': replyText,
    });
  }

  @override
  Stream<List<Comment>> watchPublishedByBarbershop(String barbershopId) {
    return _firestore
        .collection('comments')
        .where('barbershopId', isEqualTo: barbershopId)
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Comment.fromMap(doc.id, doc.data())).toList().reversed.toList());
  }

  @override
  Future<String> uploadPhoto({required String appointmentId, required String fileName, required Uint8List bytes}) {
    return _storage.uploadBytes(path: 'comments/$appointmentId/$fileName', bytes: bytes);
  }
}
