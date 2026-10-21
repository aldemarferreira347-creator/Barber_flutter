import 'package:barber/models/barbershop.dart';
import 'package:barber/services/cloud_shop_closure_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudShopClosureService service;

  final from = DateTime.utc(2026, 1, 10, 8);
  final until = DateTime.utc(2026, 1, 10, 12);

  Future<void> appointment(
    String id, {
    required DateTime date,
    String status = 'accepted',
    bool paid = false,
    String clientId = 'client1',
    String barberId = 'barber1',
  }) {
    return firestore.collection('appointments').doc(id).set({
      'barbershopId': 'shop1',
      'barberId': barberId,
      'clientId': clientId,
      'serviceName': 'Corte',
      'date': Timestamp.fromDate(date),
      'status': status,
      'paid': paid,
      'forcedRatingPenalty': false,
    });
  }

  Future<Map<String, dynamic>> read(String collection, String id) async =>
      (await firestore.collection(collection).doc(id).get()).data()!;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner1');
    service = CloudShopClosureService(firestore: firestore, auth: auth);
    await firestore.collection('barbershops').doc('shop1').set({
      'name': 'BarberFlow',
      'ownerId': 'owner1',
    });
  });

  test('aplaza las pagadas del rango, libera el horario y penaliza la calificación', () async {
    await appointment('appt1', date: DateTime.utc(2026, 1, 10, 10), paid: true);
    await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-01-10T10:00')
        .set({'appointmentId': 'appt1', 'barberId': 'barber1'});
    // Fuera de rango: no se toca.
    await appointment('appt2', date: DateTime.utc(2026, 1, 10, 14), paid: true);

    final result = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Corte de energía',
    );

    expect(result.postponed, 1);
    expect(result.cancelled, 0);
    final appt1 = await read('appointments', 'appt1');
    expect(appt1['status'], 'postponed');
    expect(appt1['forcedRatingPenalty'], true);
    expect(
      (await firestore
              .collection('appointmentSlots')
              .doc('barber1_2026-01-10T10:00')
              .get())
          .exists,
      false,
    );
    expect((await read('appointments', 'appt2'))['status'], 'accepted');
  });

  test('las citas SIN pago del rango se cancelan, sin penalización', () async {
    await appointment('unpaid', date: DateTime.utc(2026, 1, 10, 9));
    await appointment(
      'pending',
      date: DateTime.utc(2026, 1, 10, 11),
      status: 'pending',
    );
    // Ya terminada o cancelada: no cuenta.
    await appointment(
      'done',
      date: DateTime.utc(2026, 1, 10, 9),
      status: 'completed',
    );

    final result = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Emergencia',
    );

    expect(result.cancelled, 2);
    expect((await read('appointments', 'unpaid'))['status'], 'cancelled');
    expect(
      (await read('appointments', 'unpaid'))['forcedRatingPenalty'],
      false,
    );
    expect((await read('appointments', 'pending'))['status'], 'cancelled');
    expect((await read('appointments', 'done'))['status'], 'completed');
  });

  test('cada cliente afectado recibe un aviso con id determinista', () async {
    await appointment('a1', date: DateTime.utc(2026, 1, 10, 9), paid: true);
    await appointment(
      'a2',
      date: DateTime.utc(2026, 1, 10, 10),
      clientId: 'client2',
    );
    await firestore.collection('purchases').doc('p1').set({
      'barbershopId': 'shop1',
      'buyerId': 'client3',
      'status': 'pending_claim',
    });
    // Compra ya entregada: no se avisa.
    await firestore.collection('purchases').doc('p2').set({
      'barbershopId': 'shop1',
      'buyerId': 'client4',
      'status': 'claimed',
    });

    final result = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Corte de energía',
    );

    expect(result.notificationsSent, 3);
    expect(result.notificationsFailed, 0);
    expect(result.purchasesNotified, 1);
    final notices = (await firestore.collection('notifications').get()).docs;
    expect(notices.length, 3);
    final closureId =
        (await firestore.collection('shopClosures').get()).docs.single.id;
    final byId = {for (final d in notices) d.id: d.data()};
    expect(byId.keys, {
      'closure_${closureId}_a1',
      'closure_${closureId}_a2',
      'closure_${closureId}_p1',
    });
    final paid = byId['closure_${closureId}_a1']!;
    expect(paid['toUserId'], 'client1');
    expect(paid['type'], 'shop_closure');
    expect(paid['read'], false);
    expect(paid['title'], contains('aplazada'));
    expect(paid['body'], contains('Corte de energía'));
    expect(byId['closure_${closureId}_a2']!['title'], contains('cancelada'));
  });

  test(
    'sin fecha de regreso afecta todo lo futuro y lo dice en el aviso',
    () async {
      await appointment('soon', date: DateTime.utc(2026, 1, 10, 9), paid: true);
      await appointment('later', date: DateTime.utc(2026, 3, 1, 9), paid: true);
      // Antes del cierre: no se toca.
      await appointment('past', date: DateTime.utc(2026, 1, 9, 9), paid: true);

      final result = await service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: from,
        reason: 'Remodelación',
      );

      expect(result.postponed, 2);
      expect((await read('appointments', 'past'))['status'], 'accepted');
      final closure = (await firestore.collection('shopClosures').get())
          .docs
          .single
          .data();
      expect(closure['closedUntil'], isNull);
      expect(closure['appointmentsAffected'], 2);
      expect(closure['notificationsSent'], 2);
      final shop = Barbershop.fromMap(
        'shop1',
        (await firestore.collection('barbershops').doc('shop1').get()).data()!,
      );
      expect(shop.closure, isNotNull);
      expect(shop.closure!.isIndefinite, true);
      expect(shop.isClosedNow(DateTime.utc(2027, 1, 5)), true);
      expect(shop.isClosedNow(DateTime.utc(2026, 1, 9)), false);
      final notice = (await firestore.collection('notifications').get())
          .docs
          .first
          .data();
      expect(notice['body'], contains('hasta nuevo aviso'));
    },
  );

  test(
    'con fecha de regreso la barbería queda cerrada solo en esa ventana',
    () async {
      await service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: from,
        closedUntil: until,
        reason: 'Emergencia',
      );
      final shop = Barbershop.fromMap(
        'shop1',
        (await firestore.collection('barbershops').doc('shop1').get()).data()!,
      );
      expect(shop.isClosedNow(DateTime.utc(2026, 1, 10, 9)), true);
      expect(shop.isClosedNow(DateTime.utc(2026, 1, 10, 12, 1)), false);
      expect(
        shop.isClosedDuring(
          DateTime.utc(2026, 1, 10, 11, 30),
          DateTime.utc(2026, 1, 10, 12, 30),
        ),
        true,
      );
      expect(
        shop.isClosedDuring(
          DateTime.utc(2026, 1, 10, 12),
          DateTime.utc(2026, 1, 10, 13),
        ),
        false,
      );
    },
  );

  test('previewImpact cuenta lo que pasaría sin cambiar nada', () async {
    await appointment('p', date: DateTime.utc(2026, 1, 10, 9), paid: true);
    await appointment('u', date: DateTime.utc(2026, 1, 10, 10));
    await firestore.collection('purchases').doc('b1').set({
      'barbershopId': 'shop1',
      'buyerId': 'c',
      'status': 'pending_payment',
    });

    final impact = await service.previewImpact(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
    );

    expect(impact.paidAppointments, 1);
    expect(impact.unpaidAppointments, 1);
    expect(impact.purchases, 1);
    expect(impact.total, 3);
    expect((await read('appointments', 'p'))['status'], 'accepted');
    expect((await firestore.collection('notifications').get()).docs, isEmpty);
  });

  test('reopen quita el cierre y marca el registro como terminado', () async {
    await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      reason: 'Remodelación',
    );

    await service.reopen('shop1');

    final shop = (await firestore.collection('barbershops').doc('shop1').get())
        .data()!;
    expect(shop.containsKey('closure'), false);
    final closure = (await firestore.collection('shopClosures').get())
        .docs
        .single
        .data();
    expect(closure['endedAt'], isNotNull);
  });

  test('sin reservas afectadas el cierre se aplica igual', () async {
    final result = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Emergencia',
    );
    expect(result.appointmentsAffected, 0);
    expect(result.notificationsSent, 0);
  });

  test('rechaza un rango inválido y un motivo vacío', () async {
    await expectLater(
      () => service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: DateTime.utc(2026, 1, 10, 12),
        closedUntil: DateTime.utc(2026, 1, 10, 8),
        reason: 'Emergencia',
      ),
      throwsA(anything),
    );
    await expectLater(
      () => service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: from,
        reason: '   ',
      ),
      throwsA(anything),
    );
    expect((await firestore.collection('shopClosures').get()).docs, isEmpty);
  });
}
