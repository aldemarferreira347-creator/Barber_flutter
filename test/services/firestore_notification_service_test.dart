import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:barber/models/app_notification.dart';
import 'package:barber/services/firestore_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreNotificationService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = FirestoreNotificationService(firestore: firestore);
  });

  test('send guarda la notificación sin leer, con el tipo indicado', () async {
    await service.send(
      toUserId: 'user1',
      title: 'Pago vencido',
      body: 'Regulariza tu mensualidad',
    );

    final snapshot = await firestore.collection('notifications').get();
    final doc = snapshot.docs.single.data();
    expect(doc['toUserId'], 'user1');
    expect(doc['title'], 'Pago vencido');
    expect(doc['body'], 'Regulariza tu mensualidad');
    expect(doc['type'], 'manual');
    expect(doc['read'], false);
  });

  test('send acepta la categoría autoPaymentOverdue', () async {
    await service.send(
      toUserId: 'user1',
      title: 'Pago vencido',
      body: 'Tu mensualidad venció',
      type: NotificationType.autoPaymentOverdue,
    );

    final snapshot = await firestore.collection('notifications').get();
    expect(snapshot.docs.single.data()['type'], 'auto_payment_overdue');
  });

  test('send rechaza un título vacío', () async {
    await expectLater(
      () => service.send(toUserId: 'user1', title: '  ', body: 'Mensaje'),
      throwsA(anything),
    );
  });

  test('markRead marca la notificación como leída', () async {
    await firestore.collection('notifications').doc('n1').set({
      'toUserId': 'user1',
      'title': 't',
      'body': 'b',
      'type': 'manual',
      'read': false,
    });

    await service.markRead('n1');

    final doc = (await firestore.collection('notifications').doc('n1').get())
        .data()!;
    expect(doc['read'], true);
  });

  test('watchForUser devuelve las notificaciones de ese usuario', () async {
    await firestore.collection('notifications').doc('n1').set({
      'toUserId': 'user1',
      'title': 't1',
      'body': 'b1',
      'type': 'manual',
      'read': false,
    });
    await firestore.collection('notifications').doc('n2').set({
      'toUserId': 'other',
      'title': 't2',
      'body': 'b2',
      'type': 'manual',
      'read': false,
    });

    final notifications = await service.watchForUser('user1').first;

    expect(notifications, hasLength(1));
    expect(notifications.single.title, 't1');
  });
}
