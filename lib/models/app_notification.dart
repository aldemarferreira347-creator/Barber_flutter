import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { manual, autoPaymentOverdue }

extension NotificationTypeX on NotificationType {
  String get value => switch (this) {
        NotificationType.manual => 'manual',
        NotificationType.autoPaymentOverdue => 'auto_payment_overdue',
      };

  static NotificationType fromValue(String value) {
    return value == 'auto_payment_overdue' ? NotificationType.autoPaymentOverdue : NotificationType.manual;
  }
}

class AppNotification {
  final String id;
  final String toUserId;
  final String title;
  final String body;
  final NotificationType type;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.toUserId,
    required this.title,
    required this.body,
    this.type = NotificationType.manual,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    return AppNotification(
      id: id,
      toUserId: map['toUserId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: NotificationTypeX.fromValue(map['type'] as String? ?? 'manual'),
      read: map['read'] as bool? ?? false,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toUserId': toUserId,
      'title': title,
      'body': body,
      'type': type.value,
      'read': read,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
    };
  }
}
