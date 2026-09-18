import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/models/purchase.dart';
import 'package:barber/repositories/purchase_repository.dart';
import 'package:barber/services/cloud_purchase_service.dart';
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
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockFirebaseFirestore firestore;
  late CloudPurchaseService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    firestore = MockFirebaseFirestore();
    service = CloudPurchaseService(functions: functions, firestore: firestore);
  });

  test('createPurchase envía barbershopId, items y appointmentId, y devuelve el id', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('createPurchase')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'id': 'purchase1'});

    final id = await service.createPurchase(
      barbershopId: 'shop1',
      items: const [PurchaseItemInput(productId: 'p1', quantity: 2)],
    );

    expect(id, 'purchase1');
    verify(() => callable.call<Map<String, dynamic>>({
          'barbershopId': 'shop1',
          'items': [
            {'productId': 'p1', 'quantity': 2}
          ],
          'appointmentId': null,
        })).called(1);
  });

  test('claimPurchase llama a la función con el purchaseId', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('claimPurchase')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.claimPurchase('purchase1');

    verify(() => callable.call<void>({'purchaseId': 'purchase1'})).called(1);
  });

  test('refundItems llama a la función con purchaseId e itemIndexes', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('refundPurchaseItems')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.refundItems(purchaseId: 'purchase1', itemIndexes: [0, 2]);

    verify(() => callable.call<void>({'purchaseId': 'purchase1', 'itemIndexes': [0, 2]})).called(1);
  });

  test('watchPurchase traduce el snapshot a Purchase', () async {
    final collection = MockCollectionReference();
    final docRef = MockDocumentReference();
    final snapshot = MockDocumentSnapshot();

    when(() => firestore.collection('purchases')).thenReturn(collection);
    when(() => collection.doc('purchase1')).thenReturn(docRef);
    when(() => docRef.snapshots()).thenAnswer((_) => Stream.value(snapshot));
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.id).thenReturn('purchase1');
    when(() => snapshot.data()).thenReturn({
      'barbershopId': 'shop1',
      'buyerId': 'buyer1',
      'items': [],
      'totalAmount': 15000.0,
      'status': 'pending_claim',
    });

    final purchase = await service.watchPurchase('purchase1').first;

    expect(purchase, isNotNull);
    expect(purchase!.status, PurchaseStatus.pendingClaim);
  });

  test('findByClaimCode busca por barbershopId y claimCode dentro de esa barbería', () async {
    final collection = MockCollectionReference();
    final query1 = MockQuery();
    final query2 = MockQuery();
    final query3 = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final docSnapshot = MockQueryDocumentSnapshot();

    when(() => firestore.collection('purchases')).thenReturn(collection);
    when(() => collection.where('barbershopId', isEqualTo: 'shop1')).thenReturn(query1);
    when(() => query1.where('claimCode', isEqualTo: 'ABCD1234')).thenReturn(query2);
    when(() => query2.limit(1)).thenReturn(query3);
    when(() => query3.get()).thenAnswer((_) async => querySnapshot);
    when(() => querySnapshot.docs).thenReturn([docSnapshot]);
    when(() => docSnapshot.id).thenReturn('purchase1');
    when(() => docSnapshot.data()).thenReturn({
      'barbershopId': 'shop1',
      'buyerId': 'buyer1',
      'items': [],
      'totalAmount': 15000.0,
      'status': 'pending_claim',
      'claimCode': 'ABCD1234',
    });

    final purchase = await service.findByClaimCode(barbershopId: 'shop1', claimCode: 'abcd1234');

    expect(purchase, isNotNull);
    expect(purchase!.id, 'purchase1');
  });

  test('findByClaimCode devuelve null si no hay coincidencias', () async {
    final collection = MockCollectionReference();
    final query1 = MockQuery();
    final query2 = MockQuery();
    final query3 = MockQuery();
    final querySnapshot = MockQuerySnapshot();

    when(() => firestore.collection('purchases')).thenReturn(collection);
    when(() => collection.where('barbershopId', isEqualTo: 'shop1')).thenReturn(query1);
    when(() => query1.where('claimCode', isEqualTo: 'ZZZZ9999')).thenReturn(query2);
    when(() => query2.limit(1)).thenReturn(query3);
    when(() => query3.get()).thenAnswer((_) async => querySnapshot);
    when(() => querySnapshot.docs).thenReturn([]);

    final purchase = await service.findByClaimCode(barbershopId: 'shop1', claimCode: 'ZZZZ9999');

    expect(purchase, isNull);
  });
}
