import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/models/purchase.dart';
import 'package:barber/repositories/purchase_repository.dart';
import 'package:barber/services/cloud_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudPurchaseService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('buyer1');
    service = CloudPurchaseService(
      firestore: firestore,
      auth: auth,
      simulatedApprovalDelay: Duration.zero,
    );
  });

  Future<void> seedProduct({bool active = true, num price = 15000}) {
    return firestore
        .collection('barbershops')
        .doc('shop1')
        .collection('products')
        .doc('p1')
        .set({'name': 'Cera', 'price': price, 'active': active});
  }

  test('createPurchase recalcula el precio del catálogo, paga y entrega el código de reclamo', () async {
    await seedProduct();

    final id = await service.createPurchase(
      barbershopId: 'shop1',
      items: const [PurchaseItemInput(productId: 'p1', quantity: 2)],
    );

    final doc = (await firestore.collection('purchases').doc(id).get()).data()!;
    expect(doc['buyerId'], 'buyer1');
    expect(doc['barbershopId'], 'shop1');
    expect(doc['totalAmount'], 30000);
    expect(doc['status'], 'pending_claim');
    expect(doc['claimCode'], isA<String>());
    expect((doc['claimCode'] as String).length, 8);
    final items = List<Map<String, dynamic>>.from(doc['items'] as List);
    expect(items.single['productName'], 'Cera');
    expect(items.single['unitPrice'], 15000);
    expect(items.single['quantity'], 2);
    expect(items.single['refunded'], false);

    final paymentId = doc['paymentId'] as String;
    final payment =
        (await firestore.collection('payments').doc(paymentId).get()).data()!;
    expect(payment['status'], 'approved');
    expect(payment['category'], 'product');
    expect(payment['amount'], 30000);
    expect(payment['relatedId'], id);
  });

  test('createPurchase rechaza un producto inactivo', () async {
    await seedProduct(active: false);

    await expectLater(
      () => service.createPurchase(
        barbershopId: 'shop1',
        items: const [PurchaseItemInput(productId: 'p1', quantity: 1)],
      ),
      throwsA(anything),
    );
  });

  test('createPurchase rechaza más de 5 ítems', () async {
    await seedProduct();

    await expectLater(
      () => service.createPurchase(
        barbershopId: 'shop1',
        items: List.generate(
          6,
          (_) => const PurchaseItemInput(productId: 'p1', quantity: 1),
        ),
      ),
      throwsA(anything),
    );
  });

  test('claimPurchase marca la compra como reclamada', () async {
    await firestore.collection('purchases').doc('purchase1').set({
      'barbershopId': 'shop1',
      'buyerId': 'buyer1',
      'items': [],
      'totalAmount': 0,
      'status': 'pending_claim',
    });

    await service.claimPurchase('purchase1');

    final doc = (await firestore.collection('purchases').doc('purchase1').get())
        .data()!;
    expect(doc['status'], 'claimed');
    expect(doc['claimedAt'], isNotNull);
  });

  test(
    'claimPurchase rechaza una compra que no está lista para reclamar',
    () async {
      await firestore.collection('purchases').doc('purchase1').set({
        'status': 'pending_payment',
      });

      await expectLater(
        () => service.claimPurchase('purchase1'),
        throwsA(anything),
      );
    },
  );

  test(
    'refundItems marca los ítems seleccionados y reembolsa el pago',
    () async {
      await firestore.collection('payments').doc('pay1').set({
        'payerId': 'buyer1',
        'amount': 45000,
        'category': 'product',
        'status': 'approved',
      });
      await firestore.collection('purchases').doc('purchase1').set({
        'paymentId': 'pay1',
        'items': [
          {
            'productId': 'p1',
            'productName': 'Cera',
            'unitPrice': 15000,
            'quantity': 1,
            'refunded': false,
          },
          {
            'productId': 'p2',
            'productName': 'Shampoo',
            'unitPrice': 30000,
            'quantity': 1,
            'refunded': false,
          },
        ],
      });

      await service.refundItems(purchaseId: 'purchase1', itemIndexes: [0]);

      final purchase =
          (await firestore.collection('purchases').doc('purchase1').get())
              .data()!;
      final items = List<Map<String, dynamic>>.from(purchase['items'] as List);
      expect(items[0]['refunded'], true);
      expect(items[1]['refunded'], false);

      final payment = (await firestore.collection('payments').doc('pay1').get())
          .data()!;
      expect(payment['status'], 'refunded');
      expect(payment['refundedAmount'], 15000);
    },
  );

  test('refundItems rechaza un ítem ya reembolsado', () async {
    await firestore.collection('purchases').doc('purchase1').set({
      'paymentId': 'pay1',
      'items': [
        {
          'productId': 'p1',
          'productName': 'Cera',
          'unitPrice': 15000,
          'quantity': 1,
          'refunded': true,
        },
      ],
    });

    await expectLater(
      () => service.refundItems(purchaseId: 'purchase1', itemIndexes: [0]),
      throwsA(anything),
    );
  });

  test('watchPurchase traduce el snapshot a Purchase', () async {
    await firestore.collection('purchases').doc('purchase1').set({
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

  test(
    'findByClaimCode busca por barbershopId y claimCode dentro de esa barbería',
    () async {
      await firestore.collection('purchases').doc('purchase1').set({
        'barbershopId': 'shop1',
        'buyerId': 'buyer1',
        'items': [],
        'totalAmount': 15000.0,
        'status': 'pending_claim',
        'claimCode': 'ABCD1234',
      });

      final purchase = await service.findByClaimCode(
        barbershopId: 'shop1',
        claimCode: 'abcd1234',
      );

      expect(purchase, isNotNull);
      expect(purchase!.id, 'purchase1');
    },
  );

  test('findByClaimCode devuelve null si no hay coincidencias', () async {
    final purchase = await service.findByClaimCode(
      barbershopId: 'shop1',
      claimCode: 'ZZZZ9999',
    );

    expect(purchase, isNull);
  });
}
