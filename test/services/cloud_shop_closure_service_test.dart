import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/services/cloud_shop_closure_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudShopClosureService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner1');
    service = CloudShopClosureService(firestore: firestore, auth: auth);
  });

  test('closeForExternalEvent aplaza las reservas pagadas del rango, libera el horario y penaliza la calificación', () async {
    final from = DateTime.utc(2026, 1, 10, 8);
    final until = DateTime.utc(2026, 1, 10, 12);

    await firestore.collection('appointments').doc('appt1').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'date': Timestamp.fromDate(DateTime.utc(2026, 1, 10, 10)),
      'status': 'accepted',
      'paid': true,
      'forcedRatingPenalty': false,
    });
    await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-01-10T10:00')
        .set({'appointmentId': 'appt1', 'barberId': 'barber1'});
    // Fuera de rango: no debe verse afectada.
    await firestore.collection('appointments').doc('appt2').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'date': Timestamp.fromDate(DateTime.utc(2026, 1, 10, 14)),
      'status': 'accepted',
      'paid': true,
      'forcedRatingPenalty': false,
    });
    // Sin pagar: no debe verse afectada.
    await firestore.collection('appointments').doc('appt3').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'date': Timestamp.fromDate(DateTime.utc(2026, 1, 10, 9)),
      'status': 'accepted',
      'paid': false,
      'forcedRatingPenalty': false,
    });

    final affected = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Corte de energía',
    );

    expect(affected, 1);

    final appt1 =
        (await firestore.collection('appointments').doc('appt1').get()).data()!;
    expect(appt1['status'], 'postponed');
    expect(appt1['forcedRatingPenalty'], true);

    final slot = await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-01-10T10:00')
        .get();
    expect(slot.exists, false);

    final appt2 =
        (await firestore.collection('appointments').doc('appt2').get()).data()!;
    expect(appt2['status'], 'accepted');

    final appt3 =
        (await firestore.collection('appointments').doc('appt3').get()).data()!;
    expect(appt3['status'], 'accepted');
  });

  test(
    'closeForExternalEvent devuelve 0 cuando no hubo reservas afectadas',
    () async {
      final affected = await service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: DateTime.utc(2026, 1, 10, 8),
        closedUntil: DateTime.utc(2026, 1, 10, 12),
        reason: 'Emergencia',
      );

      expect(affected, 0);
    },
  );

  test('closeForExternalEvent rechaza un rango inválido', () async {
    await expectLater(
      () => service.closeForExternalEvent(
        barbershopId: 'shop1',
        closedFrom: DateTime.utc(2026, 1, 10, 12),
        closedUntil: DateTime.utc(2026, 1, 10, 8),
        reason: 'Emergencia',
      ),
      throwsA(anything),
    );
  });
}
