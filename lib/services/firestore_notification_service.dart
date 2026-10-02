import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';

const _maxTitleLength = 120;
const _maxBodyLength = 1000;
const _allowedTypes = {
  NotificationType.manual,
  NotificationType.autoPaymentOverdue,
};

class FirestoreNotificationService implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirestoreNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
    // Nombre histórico del método (antes llamaba a sendNotification, Cloud
    // Function) — sin plan Blaze escribe Firestore directo; ver
    // firestore.rules: solo el admin puede crear, con la misma categoría
    // acotada que exigía el backend. Único punto de entrada usado hoy por
    // manage_users_view.dart (aviso manual) y admin_dashboard_tab.dart
    // (aviso automático de mensualidad vencida).
    //
    // Limitación aceptada: antes esto también entregaba por push/SMS/correo
    // (dispatchNotification, con canales reales) — sin servidor solo queda
    // el registro en la lista de notificaciones dentro de la app; el
    // destinatario lo ve la próxima vez que la abre, no de inmediato.
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length > _maxTitleLength) {
      throw Exception(
        'title es obligatorio (máx. $_maxTitleLength caracteres).',
      );
    }
    if (trimmedBody.isEmpty || trimmedBody.length > _maxBodyLength) {
      throw Exception('body es obligatorio (máx. $_maxBodyLength caracteres).');
    }
    if (!_allowedTypes.contains(type)) {
      throw Exception('category inválida.');
    }

    return _notifications.add({
      'toUserId': toUserId,
      'title': trimmedTitle,
      'body': trimmedBody,
      'type': type.value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markRead(String id) {
    return _notifications.doc(id).update({'read': true});
  }
}
