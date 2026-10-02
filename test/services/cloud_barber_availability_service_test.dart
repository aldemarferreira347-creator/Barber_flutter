import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/services/cloud_barber_availability_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudBarberAvailabilityService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('barber1');
    service = CloudBarberAvailabilityService(firestore: firestore, auth: auth);
  });

  test('markAway guarda awaySince y el estimado de regreso', () async {
    await firestore.collection('users').doc('barber1').set({'role': 'barber'});
    final before = DateTime.now();

    await service.markAway(30);

    final data = (await firestore.collection('users').doc('barber1').get())
        .data()!;
    expect(data['awaySince'], isA<Timestamp>());
    final estimate = (data['awayUntilEstimate'] as Timestamp).toDate();
    final expectedMinMs = before
        .add(const Duration(minutes: 30))
        .millisecondsSinceEpoch;
    expect(
      (estimate.millisecondsSinceEpoch - expectedMinMs).abs() < 5000,
      isTrue,
      reason: 'awayUntilEstimate debe quedar ~30 minutos después de ahora',
    );
  });

  test('markAway rechaza un estimado fuera de 5 a 240 minutos', () async {
    await firestore.collection('users').doc('barber1').set({'role': 'barber'});

    await expectLater(() => service.markAway(2), throwsA(anything));
    await expectLater(() => service.markAway(241), throwsA(anything));
  });

  test('markReturned limpia awaySince y awayUntilEstimate', () async {
    await firestore.collection('users').doc('barber1').set({
      'role': 'barber',
      'awaySince': Timestamp.now(),
      'awayUntilEstimate': Timestamp.now(),
    });

    await service.markReturned();

    final data = (await firestore.collection('users').doc('barber1').get())
        .data()!;
    expect(data['awaySince'], isNull);
    expect(data['awayUntilEstimate'], isNull);
  });
}
