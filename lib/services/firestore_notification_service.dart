import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';

class FirestoreNotificationService implements NotificationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirestoreNotificationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  @override
  Stream<List<AppNotification>> watchForUser(String uid) {
    return _notifications
        .where('toUserId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> send({
    required String toUserId,
    required String title,
    required String body,
    NotificationType type = NotificationType.manual,
  }) {
    // El envío en sí (registrar la notificación + entregarla por push, y si
    // hace falta por SMS/correo) corre en el backend (functions/src/
    // notifications/notificationDispatcher.ts) — el cliente nunca escribe
    // notifications/{id} directamente (ver firestore.rules: create: false).
    return _functions.httpsCallable('sendNotification').call<void>({
      'toUserId': toUserId,
      'title': title,
      'body': body,
      'category': type.value,
    });
  }

  @override
  Future<void> markRead(String id) {
    return _notifications.doc(id).update({'read': true});
  }
}
