import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';

class FirestoreNotificationService implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirestoreNotificationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications => _firestore.collection('notifications');

  @override
  Stream<List<AppNotification>> watchForUser(String uid) {
    return _notifications.where('toUserId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> send({required String toUserId, required String title, required String body, NotificationType type = NotificationType.manual}) {
    return _notifications.add(AppNotification(id: '', toUserId: toUserId, title: title, body: body, type: type).toMap());
  }

  @override
  Future<void> markRead(String id) {
    return _notifications.doc(id).update({'read': true});
  }
}
