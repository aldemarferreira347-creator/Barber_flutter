import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/firestore_barbershop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageRepository extends Mock implements StorageRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late MockStorageRepository storage;
  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late FirestoreBarbershopService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    storage = MockStorageRepository();
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    when(() => firestore.collection('barbershops')).thenReturn(collection);
    service = FirestoreBarbershopService(
      storage: storage,
      firestore: firestore,
      simulatedApprovalDelay: Duration.zero,
    );
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

    verify(
      () => storage.uploadBytes(
        path: 'barbershops/shop1/profile/cover.png',
        bytes: bytes,
      ),
    ).called(1);
    verify(() => docRef.update({'photoUrl': 'https://example.com/shop.png'}))
        .called(1);
  });

  test('watchApproved filtra por approvalStatus aprobada y activa', () async {
    final query1 = MockQuery();
    final query2 = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final doc = MockQueryDocumentSnapshot();

    when(() => collection.where('approvalStatus', isEqualTo: 'approved'))
        .thenReturn(query1);
    when(() => query1.where('active', isEqualTo: true)).thenReturn(query2);
    when(() => query2.snapshots())
        .thenAnswer((_) => Stream.value(querySnapshot));
    when(() => querySnapshot.docs).thenReturn([doc]);
    when(() => doc.id).thenReturn('shop1');
    when(() => doc.data()).thenReturn({
      'name': 'BarberFlow',
      'ownerId': 'owner1',
      'active': true,
      'approvalStatus': 'approved',
    });

    final shops = await service.watchApproved().first;

    expect(shops, hasLength(1));
    expect(shops.first.id, 'shop1');
  });

  test('paySubscription simula el pago (payments/{id}) y renueva la mensualidad 30 días', () async {
    final shopDocRef = MockDocumentReference();
    final shopSnap = MockDocumentSnapshot();
    final paymentsCollection = MockCollectionReference();
    final paymentDocRef = MockDocumentReference();

    when(() => collection.doc('shop1')).thenReturn(shopDocRef);
    when(() => shopDocRef.get()).thenAnswer((_) async => shopSnap);
    when(() => shopSnap.id).thenReturn('shop1');
    when(() => shopSnap.data()).thenReturn({
      'name': 'BarberFlow',
      'ownerId': 'owner1',
      'approvalStatus': 'approved',
    });
    when(() => shopDocRef.update(any())).thenAnswer((_) async {});

    when(() => firestore.collection('payments')).thenReturn(paymentsCollection);
    when(() => paymentsCollection.add(any()))
        .thenAnswer((_) async => paymentDocRef);
    when(() => paymentDocRef.update(any())).thenAnswer((_) async {});

    when(() => paymentDocRef.id).thenReturn('pay1');

    await service.paySubscription('shop1');

    final paymentCreate = Map<String, dynamic>.from(
      verify(() => paymentsCollection.add(captureAny())).captured.single as Map,
    );
    expect(paymentCreate['payerId'], 'owner1');
    expect(paymentCreate['category'], 'subscription');
    expect(paymentCreate['relatedId'], 'shop1');
    expect(paymentCreate['status'], 'pending');

    final paymentResolve = Map<String, dynamic>.from(
      verify(() => paymentDocRef.update(captureAny())).captured.single as Map,
    );
    expect(paymentResolve['status'], 'approved');

    final shopUpdate = Map<String, dynamic>.from(
      verify(() => shopDocRef.update(captureAny())).captured.single as Map,
    );
    expect(shopUpdate['paymentStatus'], 'ok');
    expect(shopUpdate['active'], true);
    final dueDate = (shopUpdate['paymentDueDate'] as Timestamp).toDate();
    final daysAhead = dueDate.difference(DateTime.now()).inHours / 24;
    expect(daysAhead, greaterThan(29));
    expect(daysAhead, lessThan(31));
  });

  test('cancelSubscription bloquea la barbería de inmediato, sin período de gracia', () async {
    final docRef = MockDocumentReference();
    when(() => collection.doc('shop1')).thenReturn(docRef);
    when(() => docRef.update(any())).thenAnswer((_) async {});

    await service.cancelSubscription('shop1');

    verify(() => docRef.update({'paymentStatus': 'blocked', 'active': false}))
        .called(1);
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

      final captured = Map<String, dynamic>.from(
        verify(() => docRef.update(captureAny())).captured.single as Map,
      );
      expect(captured['approvalStatus'], 'approved');
      expect(captured['active'], true);
      expect(captured['paymentStatus'], 'ok');
      final dueDate = (captured['paymentDueDate'] as Timestamp).toDate();
      final daysAhead = dueDate.difference(DateTime.now()).inHours / 24;
      expect(daysAhead, greaterThan(29));
      expect(daysAhead, lessThan(31));
    });
  });

  group('borradores (máximo $kMaxBarbershopDrafts, cupos {uid}_1..5)', () {
    late MockCollectionReference drafts;
    late MockTransaction tx;

    setUp(() {
      drafts = MockCollectionReference();
      tx = MockTransaction();
      registerFallbackValue(MockDocumentReference());
      registerFallbackValue(Duration.zero);
      when(() => firestore.collection('barbershopDrafts')).thenReturn(drafts);
      when(
        () => firestore.runTransaction<bool>(
          any(),
          timeout: any(named: 'timeout'),
          maxAttempts: any(named: 'maxAttempts'),
        ),
      ).thenAnswer((invocation) async {
        final handler =
            invocation.positionalArguments.first as TransactionHandler<bool>;
        return handler(tx);
      });
      when(() => tx.set<Map<String, dynamic>>(any(), any())).thenReturn(tx);
    });

    MockDocumentReference slot(int n, {required bool taken}) {
      final ref = MockDocumentReference();
      final snap = MockDocumentSnapshot();
      when(() => ref.id).thenReturn('owner1_$n');
      when(() => snap.exists).thenReturn(taken);
      when(() => drafts.doc('owner1_$n')).thenReturn(ref);
      when(() => tx.get(ref)).thenAnswer((_) async => snap);
      return ref;
    }

    const draft = Barbershop(id: '', name: 'Borrador', ownerId: 'owner1');

    test('saveDraft usa el primer cupo libre', () async {
      slot(1, taken: true);
      final free = slot(2, taken: false);

      final id = await service.saveDraft(draft);

      expect(id, 'owner1_2');
      final data = Map<String, dynamic>.from(
        verify(() => tx.set<Map<String, dynamic>>(free, captureAny()))
                .captured
                .single
            as Map,
      );
      expect(data['ownerId'], 'owner1');
      expect(data['name'], 'Borrador');
      // Un borrador no lleva estados de aprobación ni de pago.
      expect(data.containsKey('approvalStatus'), false);
      expect(data.containsKey('paymentStatus'), false);
      expect(data.containsKey('active'), false);
    });

    test(
      'saveDraft lanza BarbershopDraftLimitException con los 5 cupos ocupados',
      () async {
        for (var n = 1; n <= kMaxBarbershopDrafts; n++) {
          slot(n, taken: true);
        }

        expect(
          () => service.saveDraft(draft),
          throwsA(isA<BarbershopDraftLimitException>()),
        );
      },
    );

    test('publishDraft cobra, crea la barbería pendiente con su paymentId y borra el borrador', () async {
      final draftRef = MockDocumentReference();
      final draftSnap = MockDocumentSnapshot();
      when(() => drafts.doc('owner1_1')).thenReturn(draftRef);
      when(() => draftRef.get()).thenAnswer((_) async => draftSnap);
      when(() => draftSnap.id).thenReturn('owner1_1');
      when(() => draftSnap.data()).thenReturn({
        'name': 'Mi barbería',
        'ownerId': 'owner1',
        'address': 'Calle 1',
      });

      final shopRef = MockDocumentReference();
      when(() => shopRef.id).thenReturn('newShop');
      when(() => collection.doc()).thenReturn(shopRef);

      final paymentsCollection = MockCollectionReference();
      final paymentRef = MockDocumentReference();
      when(() => firestore.collection('payments'))
          .thenReturn(paymentsCollection);
      when(() => paymentsCollection.add(any()))
          .thenAnswer((_) async => paymentRef);
      when(() => paymentRef.id).thenReturn('pay1');
      when(() => paymentRef.update(any())).thenAnswer((_) async {});

      final batch = MockWriteBatch();
      when(() => firestore.batch()).thenReturn(batch);
      when(() => batch.set<Map<String, dynamic>>(any(), any()))
          .thenReturn(null);
      when(() => batch.delete(any())).thenReturn(null);
      when(() => batch.commit()).thenAnswer((_) async {});

      final id = await service.publishDraft('owner1_1');

      expect(id, 'newShop');
      final payment = Map<String, dynamic>.from(
        verify(() => paymentsCollection.add(captureAny())).captured.single
            as Map,
      );
      expect(payment['payerId'], 'owner1');
      expect(payment['category'], 'subscription');
      expect(payment['relatedId'], 'newShop');
      expect(payment['amount'], kBarbershopMonthlyFee);
      final resolve = Map<String, dynamic>.from(
        verify(() => paymentRef.update(captureAny())).captured.single as Map,
      );
      expect(resolve['status'], 'approved');

      final shop = Map<String, dynamic>.from(
        verify(() => batch.set<Map<String, dynamic>>(shopRef, captureAny()))
                .captured
                .single
            as Map,
      );
      expect(shop['approvalStatus'], 'pending');
      expect(shop['active'], false);
      expect(shop['paymentId'], 'pay1');
      expect(shop['ownerId'], 'owner1');
      verify(() => batch.delete(draftRef)).called(1);
      verify(() => batch.commit()).called(1);
    });

    test('createPaid no toca ningún borrador', () async {
      final shopRef = MockDocumentReference();
      when(() => shopRef.id).thenReturn('newShop');
      when(() => collection.doc()).thenReturn(shopRef);
      final paymentsCollection = MockCollectionReference();
      final paymentRef = MockDocumentReference();
      when(() => firestore.collection('payments'))
          .thenReturn(paymentsCollection);
      when(() => paymentsCollection.add(any()))
          .thenAnswer((_) async => paymentRef);
      when(() => paymentRef.id).thenReturn('pay1');
      when(() => paymentRef.update(any())).thenAnswer((_) async {});
      final batch = MockWriteBatch();
      when(() => firestore.batch()).thenReturn(batch);
      when(() => batch.set<Map<String, dynamic>>(any(), any()))
          .thenReturn(null);
      when(() => batch.commit()).thenAnswer((_) async {});

      await service.createPaid(draft);

      verifyNever(() => batch.delete(any()));
      verify(() => batch.commit()).called(1);
    });
  });
}
