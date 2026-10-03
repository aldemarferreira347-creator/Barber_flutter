import 'package:cloud_firestore/cloud_firestore.dart';
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
    service = CloudPurchaseService(firestore: firestore, auth: auth);
  });

  Future<void> seedProduct({bool active = true, num price = 15000}) {
    return firestore
        .collection('barbershops')
        .doc('shop1')
        .collection('products')
        .doc('p1')
        .set({'name': 'Cera', 'price': price, 'active': active});
  }

  test('createPurchase recalcula el precio del catálogo y deja el pago Nequi pendiente de verificar', () async {
    await seedProduct();

    final id = await service.createPurchase(
      barbershopId: 'shop1',
      items: const [PurchaseItemInput(productId: 'p1', quantity: 2)],
      reference: 'M1234567',
    );

    final doc = (await firestore.collection('purchases').doc(id).get()).data()!;
    expect(doc['buyerId'], 'buyer1');
    expect(doc['barbershopId'], 'shop1');
    expect(doc['totalAmount'], 30000);
    // Sin verificar el dinero todavía no hay código ni plazo de reclamo.
    expect(doc['status'], 'pending_payment');
    expect(doc['claimCode'], isNull);
    expect(doc['expiresAt'], isNull);
    final items = List<Map<String, dynamic>>.from(doc['items'] as List);
    expect(items.single['productName'], 'Cera');
    expect(items.single['unitPrice'], 15000);
    expect(items.single['quantity'], 2);
    expect(items.single['refunded'], false);

    final paymentId = doc['paymentId'] as String;
    final payment =
        (await firestore.collection('payments').doc(paymentId).get()).data()!;
    expect(payment['status'], 'pending');
    expect(payment['category'], 'product');
    expect(payment['amount'], 30000);
    expect(payment['relatedId'], id);
    expect(payment['payerId'], 'buyer1');
    expect(payment['reference'], 'M1234567');
    expect(payment['method'], 'nequi');
  });

  group('verificación del pago por el personal', () {
    late String purchaseId;

    setUp(() async {
      await seedProduct();
      purchaseId = await service.createPurchase(
        barbershopId: 'shop1',
        items: const [PurchaseItemInput(productId: 'p1', quantity: 1)],
        reference: 'M7654321',
      );
      // A partir de aquí actúa el personal de la barbería.
      when(() => user.uid).thenReturn('barber1');
    });

    test(
      'confirmPayment aprueba el pago y entrega código y 24 h de plazo',
      () async {
        await service.confirmPayment(purchaseId);

        final purchase =
            (await firestore.collection('purchases').doc(purchaseId).get())
                .data()!;
        expect(purchase['status'], 'pending_claim');
        expect(purchase['claimCode'], matches(RegExp(r'^[0-9A-Z]{8}$')));
        final expiresAt = (purchase['expiresAt'] as Timestamp).toDate();
        expect(
          expiresAt.difference(DateTime.now()).inHours,
          inInclusiveRange(23, 24),
        );

        final payment =
            (await firestore
                    .collection('payments')
                    .doc(purchase['paymentId'] as String)
                    .get())
                .data()!;
        expect(payment['status'], 'approved');
        expect(payment['resolvedBy'], 'barber1');
      },
    );

    test('rejectPayment rechaza el pago y deja la compra fallida', () async {
      await service.rejectPayment(purchaseId);

      final purchase =
          (await firestore.collection('purchases').doc(purchaseId).get())
              .data()!;
      expect(purchase['status'], 'payment_failed');
      expect(purchase['claimCode'], isNull);
      final payment =
          (await firestore
                  .collection('payments')
                  .doc(purchase['paymentId'] as String)
                  .get())
              .data()!;
      expect(payment['status'], 'rejected');
    });

    test('un pago ya resuelto no se puede volver a confirmar', () async {
      await service.confirmPayment(purchaseId);
      await expectLater(
        () => service.confirmPayment(purchaseId),
        throwsA(anything),
      );
      await expectLater(
        () => service.rejectPayment(purchaseId),
        throwsA(anything),
      );
    });
  });

  test('createPurchase rechaza un producto inactivo', () async {
    await seedProduct(active: false);

    await expectLater(
      () => service.createPurchase(
        barbershopId: 'shop1',
        items: const [PurchaseItemInput(productId: 'p1', quantity: 1)],
        reference: 'M1234567',
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
        reference: 'M1234567',
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
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 5)),
      ),
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

  test('claimPurchase rechaza una compra vencida', () async {
    await firestore.collection('purchases').doc('purchase1').set({
      'barbershopId': 'shop1',
      'buyerId': 'buyer1',
      'items': [],
      'totalAmount': 0,
      'status': 'pending_claim',
      'expiresAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    });

    await expectLater(
      () => service.claimPurchase('purchase1'),
      throwsA(anything),
    );
    final doc = (await firestore.collection('purchases').doc('purchase1').get())
        .data()!;
    expect(doc['status'], 'pending_claim');
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
