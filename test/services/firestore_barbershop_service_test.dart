import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/firestore_barbershop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageRepository extends Mock implements StorageRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  late MockStorageRepository storage;
  late MockFirebaseFirestore firestore;
  late MockFirebaseFunctions functions;
  late MockCollectionReference collection;
  late FirestoreBarbershopService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    storage = MockStorageRepository();
    firestore = MockFirebaseFirestore();
    functions = MockFirebaseFunctions();
    collection = MockCollectionReference();
    when(() => firestore.collection('barbershops')).thenReturn(collection);
    service = FirestoreBarbershopService(storage: storage, firestore: firestore, functions: functions);
  });

  test('uploadPhoto sube la foto y guarda su URL en el documento', () async {
    final docRef = MockDocumentReference();
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'https://example.com/shop.png');
    when(() => collection.doc('shop1')).thenReturn(docRef);
    when(() => docRef.update(any())).thenAnswer((_) async {});

    final bytes = Uint8List.fromList([1, 2, 3]);
    await service.uploadPhoto('shop1', fileName: 'cover.png', bytes: bytes);

    verify(() => storage.uploadBytes(path: 'barbershops/shop1/profile/cover.png', bytes: bytes)).called(1);
    verify(() => docRef.update({'photoUrl': 'https://example.com/shop.png'})).called(1);
  });

  test('watchApproved filtra por approvalStatus aprobada y activa', () async {
    final query1 = MockQuery();
    final query2 = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final doc = MockQueryDocumentSnapshot();

    when(() => collection.where('approvalStatus', isEqualTo: 'approved')).thenReturn(query1);
    when(() => query1.where('active', isEqualTo: true)).thenReturn(query2);
    when(() => query2.snapshots()).thenAnswer((_) => Stream.value(querySnapshot));
    when(() => querySnapshot.docs).thenReturn([doc]);
    when(() => doc.id).thenReturn('shop1');
    when(() => doc.data())
        .thenReturn({'name': 'BarberFlow', 'ownerId': 'owner1', 'active': true, 'approvalStatus': 'approved'});

    final shops = await service.watchApproved().first;

    expect(shops, hasLength(1));
    expect(shops.first.id, 'shop1');
  });

  test('requestOwnership llama a la función con el barbershopId', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('requestBarbershopOwnership')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => MockHttpsCallableResult<Map<String, dynamic>>());

    await service.requestOwnership('shop1');

    verify(() => callable.call<Map<String, dynamic>>({'barbershopId': 'shop1'})).called(1);
  });

  test('paySubscription llama a la función con el barbershopId', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('payBarbershopSubscription')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => MockHttpsCallableResult<Map<String, dynamic>>());

    await service.paySubscription('shop1');

    verify(() => callable.call<Map<String, dynamic>>({'barbershopId': 'shop1'})).called(1);
  });

  test('cancelSubscription llama a la función con el barbershopId', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('cancelBarbershopSubscription')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => MockHttpsCallableResult<Map<String, dynamic>>());

    await service.cancelSubscription('shop1');

    verify(() => callable.call<Map<String, dynamic>>({'barbershopId': 'shop1'})).called(1);
  });

  group('resolveApproval', () {
    test('approve: false solo marca rechazada', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('shop1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.resolveApproval('shop1', approve: false);

      verify(() => docRef.update({'approvalStatus': 'rejected'})).called(1);
    });

    test('approve: true activa la barbería y arranca el primer ciclo de mensualidad', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('shop1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      await service.resolveApproval('shop1', approve: true);

      final captured = Map<String, dynamic>.from(verify(() => docRef.update(captureAny())).captured.single as Map);
      expect(captured['approvalStatus'], 'approved');
      expect(captured['active'], true);
      expect(captured['paymentStatus'], 'ok');
      final dueDate = (captured['paymentDueDate'] as Timestamp).toDate();
      final daysAhead = dueDate.difference(DateTime.now()).inHours / 24;
      expect(daysAhead, greaterThan(29));
      expect(daysAhead, lessThan(31));
    });
  });
}
