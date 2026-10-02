import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/services/cloud_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Firestore usa FakeFirebaseFirestore (no mocktail) porque submitRating
// hace un create() seguido de dos update() con FieldValue.increment(), y
// queremos verificar el valor final resuelto, no solo que se llamó update().
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudRatingService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('client1');
    service = CloudRatingService(firestore: firestore, auth: auth);
  });

  Future<void> seedAppointment({
    bool paid = true,
    String status = 'completed',
    bool forcedRatingPenalty = false,
    String clientId = 'client1',
  }) {
    return firestore.collection('appointments').doc('appt1').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': clientId,
      'paid': paid,
      'status': status,
      'forcedRatingPenalty': forcedRatingPenalty,
    });
  }

  Future<void> seedAggregates({int shopSum = 10, int shopCount = 2, int barberSum = 8, int barberCount = 2}) async {
    await firestore.collection('barbershops').doc('shop1').set({
      'ratingSum': shopSum,
      'ratingCount': shopCount,
    });
    await firestore.collection('users').doc('barber1').set({
      'role': 'barber',
      'ratingSum': barberSum,
      'ratingCount': barberCount,
    });
  }

  test('submitRating crea el rating y suma el promedio de la barbería y del barbero', () async {
    await seedAppointment();
    await seedAggregates();

    await service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 4);

    final rating = (await firestore.collection('ratings').doc('appt1').get()).data()!;
    expect(rating['appointmentId'], 'appt1');
    expect(rating['barbershopId'], 'shop1');
    expect(rating['barberId'], 'barber1');
    expect(rating['clientId'], 'client1');
    expect(rating['barberStars'], 5);
    expect(rating['shopStars'], 4);
    expect(rating['effectiveShopStars'], 4);
    expect(rating['forcedRatingPenaltyApplied'], false);

    final shop = (await firestore.collection('barbershops').doc('shop1').get()).data()!;
    expect(shop['ratingSum'], 14);
    expect(shop['ratingCount'], 3);

    final barber = (await firestore.collection('users').doc('barber1').get()).data()!;
    expect(barber['ratingSum'], 13);
    expect(barber['ratingCount'], 3);
  });

  test('submitRating descuenta 1 estrella de la barbería si forcedRatingPenalty está activo', () async {
    await seedAppointment(forcedRatingPenalty: true);
    await seedAggregates();

    await service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 3);

    final rating = (await firestore.collection('ratings').doc('appt1').get()).data()!;
    expect(rating['effectiveShopStars'], 2);
    expect(rating['forcedRatingPenaltyApplied'], true);

    final shop = (await firestore.collection('barbershops').doc('shop1').get()).data()!;
    expect(shop['ratingSum'], 12); // 10 + 2, no 10 + 3
  });

  test('submitRating nunca baja de 1 estrella aunque el descuento forzado lo empuje', () async {
    await seedAppointment(forcedRatingPenalty: true);
    await seedAggregates();

    await service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 1);

    final rating = (await firestore.collection('ratings').doc('appt1').get()).data()!;
    expect(rating['effectiveShopStars'], 1);
  });

  test('submitRating rechaza calificar la cita de otro cliente', () async {
    await seedAppointment(clientId: 'other-client');
    await seedAggregates();

    await expectLater(
      () => service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 5),
      throwsA(anything),
    );
  });

  test('submitRating rechaza una cita no pagada o no completada', () async {
    await seedAppointment(status: 'accepted');
    await seedAggregates();

    await expectLater(
      () => service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 5),
      throwsA(anything),
    );
  });

  test('submitRating rechaza estrellas fuera de 1 a 5', () async {
    await seedAppointment();
    await seedAggregates();

    await expectLater(
      () => service.submitRating(appointmentId: 'appt1', barberStars: 6, shopStars: 5),
      throwsA(anything),
    );
  });

  test('watchRatedAppointmentIds devuelve los ids de los documentos calificados por ese cliente', () async {
    await firestore.collection('ratings').doc('appt1').set({'clientId': 'client1'});
    await firestore.collection('ratings').doc('appt2').set({'clientId': 'client1'});
    await firestore.collection('ratings').doc('appt3').set({'clientId': 'other'});

    final ids = await service.watchRatedAppointmentIds('client1').first;

    expect(ids, {'appt1', 'appt2'});
  });
}
