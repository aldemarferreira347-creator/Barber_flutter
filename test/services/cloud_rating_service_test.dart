import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/services/cloud_rating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockFirebaseFirestore firestore;
  late CloudRatingService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    firestore = MockFirebaseFirestore();
    service = CloudRatingService(functions: functions, firestore: firestore);
  });

  test('submitRating envía appointmentId, barberStars y shopStars', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('submitAppointmentRating')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => MockHttpsCallableResult<Map<String, dynamic>>());

    await service.submitRating(appointmentId: 'appt1', barberStars: 5, shopStars: 4);

    verify(() => callable.call<Map<String, dynamic>>({'appointmentId': 'appt1', 'barberStars': 5, 'shopStars': 4}))
        .called(1);
  });

  test('watchRatedAppointmentIds devuelve los ids de los documentos calificados por ese cliente', () async {
    final collection = MockCollectionReference();
    final query = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final doc1 = MockQueryDocumentSnapshot();
    final doc2 = MockQueryDocumentSnapshot();

    when(() => firestore.collection('ratings')).thenReturn(collection);
    when(() => collection.where('clientId', isEqualTo: 'client1')).thenReturn(query);
    when(() => query.snapshots()).thenAnswer((_) => Stream.value(querySnapshot));
    when(() => querySnapshot.docs).thenReturn([doc1, doc2]);
    when(() => doc1.id).thenReturn('appt1');
    when(() => doc2.id).thenReturn('appt2');

    final ids = await service.watchRatedAppointmentIds('client1').first;

    expect(ids, {'appt1', 'appt2'});
  });
}
