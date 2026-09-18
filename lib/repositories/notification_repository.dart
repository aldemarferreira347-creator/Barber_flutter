import '../models/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String uid);

  Future<void> send({
    required String toUserId,
    required String title,
    required String body,
    NotificationType type = NotificationType.manual,
  });

  Future<void> markRead(String id);
}
