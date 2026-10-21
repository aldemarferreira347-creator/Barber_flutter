import 'package:barber/models/purchase.dart';
import 'package:barber/models/stock_movement.dart';
import 'package:barber/repositories/inventory_repository.dart';
import 'package:barber/services/firestore_inventory_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreInventoryService service;

  DocumentReference<Map<String, dynamic>> product(String id) => firestore
      .collection('barbershops')
      .doc('shop1')
      .collection('products')
      .doc(id);

  Future<int?> stockOf(String id) async =>
      ((await product(id).get()).data()?['stock'] as num?)?.toInt();

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('barber1');
    service = FirestoreInventoryService(firestore: firestore, auth: auth);
    await firestore.collection('users').doc('barber1').set({'name': 'Beto'});
    await product('p1').set({'name': 'Cera', 'price': 15000, 'stock': 5});
    await product('pNull').set({'name': 'Gel', 'price': 9000, 'stock': null});
  });

  Future<List<Map<String, dynamic>>> movements() async =>
      (await firestore.collection('stockMovements').get()).docs
          .map((d) => d.data())
          .toList();

  test('una salida baja el stock y deja el movimiento firmado', () async {
    await service.registerMovement(
      barbershopId: 'shop1',
      productId: 'p1',
      type: StockMovementType.outbound,
      quantity: 2,
      reason: StockReason.sale,
      note: '  para un cliente ',
    );

    expect(await stockOf('p1'), 3);
    final saved = (await movements()).single;
    expect(saved['barbershopId'], 'shop1');
    expect(saved['productId'], 'p1');
    expect(saved['type'], 'out');
    expect(saved['quantity'], 2);
    expect(saved['previousStock'], 5);
    expect(saved['stockAfter'], 3);
    expect(saved['byUserId'], 'barber1');
    expect(saved['byUserName'], 'Beto');
    expect(saved['note'], 'para un cliente');
    expect((await product('p1').get()).data()!['lastMovementId'], isNotNull);
  });

  test('una entrada sube el stock', () async {
    await service.registerMovement(
      barbershopId: 'shop1',
      productId: 'p1',
      type: StockMovementType.inbound,
      quantity: 10,
      reason: StockReason.restock,
    );
    expect(await stockOf('p1'), 15);
  });

  test('un producto sin inventario empieza con una entrada', () async {
    await service.registerMovement(
      barbershopId: 'shop1',
      productId: 'pNull',
      type: StockMovementType.inbound,
      quantity: 8,
      reason: StockReason.restock,
    );
    expect(await stockOf('pNull'), 8);
    expect((await movements()).single['previousStock'], 0);
  });

  test(
    'sacar de un producto sin inventario se explica y no escribe nada',
    () async {
      await expectLater(
        service.registerMovement(
          barbershopId: 'shop1',
          productId: 'pNull',
          type: StockMovementType.outbound,
          quantity: 1,
          reason: StockReason.sale,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      expect(await stockOf('pNull'), isNull);
      expect(await movements(), isEmpty);
    },
  );

  test('no se puede sacar más de lo que hay', () async {
    await expectLater(
      service.registerMovement(
        barbershopId: 'shop1',
        productId: 'p1',
        type: StockMovementType.outbound,
        quantity: 6,
        reason: StockReason.waste,
      ),
      throwsA(
        isA<InsufficientStockException>().having(
          (e) => e.message,
          'mensaje',
          contains('Solo quedan 5'),
        ),
      ),
    );
    expect(await stockOf('p1'), 5);
  });

  test(
    'cantidades inválidas y motivos que no corresponden se rechazan',
    () async {
      await expectLater(
        service.registerMovement(
          barbershopId: 'shop1',
          productId: 'p1',
          type: StockMovementType.inbound,
          quantity: 0,
          reason: StockReason.restock,
        ),
        throwsException,
      );
      await expectLater(
        service.registerMovement(
          barbershopId: 'shop1',
          productId: 'p1',
          type: StockMovementType.inbound,
          quantity: 1,
          reason: StockReason.sale,
        ),
        throwsException,
      );
    },
  );

  test('un producto inexistente da un error claro', () async {
    await expectLater(
      service.registerMovement(
        barbershopId: 'shop1',
        productId: 'nope',
        type: StockMovementType.inbound,
        quantity: 1,
        reason: StockReason.restock,
      ),
      throwsA(predicate((e) => e.toString().contains('ya no existe'))),
    );
  });

  test(
    'watchMovements solo trae los de esa barbería, el más reciente primero',
    () async {
      await firestore.collection('stockMovements').add({
        'barbershopId': 'shop1',
        'productId': 'p1',
        'productName': 'Cera',
        'type': 'in',
        'quantity': 1,
        'reason': 'restock',
        'previousStock': 0,
        'stockAfter': 1,
        'byUserId': 'x',
        'byUserName': 'X',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 5)),
      });
      await firestore.collection('stockMovements').add({
        'barbershopId': 'shop1',
        'productId': 'p1',
        'productName': 'Cera',
        'type': 'out',
        'quantity': 1,
        'reason': 'sale',
        'previousStock': 1,
        'stockAfter': 0,
        'byUserId': 'x',
        'byUserName': 'X',
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 5)),
      });
      await firestore.collection('stockMovements').add({
        'barbershopId': 'otra',
        'productId': 'p9',
        'productName': 'Ajena',
        'type': 'in',
        'quantity': 1,
        'reason': 'restock',
        'previousStock': 0,
        'stockAfter': 1,
        'byUserId': 'x',
        'byUserName': 'X',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 5)),
      });

      final list = await service.watchMovements('shop1').first;

      expect(list.map((m) => m.reason), [
        StockReason.sale,
        StockReason.restock,
      ]);
    },
  );

  group('registerPurchaseDelivery', () {
    Purchase purchase(List<PurchaseItem> items) => Purchase(
      id: 'buy1',
      barbershopId: 'shop1',
      buyerId: 'client1',
      items: items,
      totalAmount: 0,
      status: PurchaseStatus.claimed,
    );

    test('descuenta lo entregado solo de productos con inventario', () async {
      final discounted = await service.registerPurchaseDelivery(
        purchase(const [
          PurchaseItem(
            productId: 'p1',
            productName: 'Cera',
            unitPrice: 15000,
            quantity: 2,
          ),
          PurchaseItem(
            productId: 'pNull',
            productName: 'Gel',
            unitPrice: 9000,
            quantity: 1,
          ),
        ]),
      );

      expect(discounted.discounted, 1);
      expect(discounted.failed, 0);
      expect(await stockOf('p1'), 3);
      expect(await stockOf('pNull'), isNull);
      expect((await movements()).single['reason'], 'claim');
    });

    test('nunca baja de cero aunque se entregue más de lo que había', () async {
      await service.registerPurchaseDelivery(
        purchase(const [
          PurchaseItem(
            productId: 'p1',
            productName: 'Cera',
            unitPrice: 15000,
            quantity: 9,
          ),
        ]),
      );
      expect(await stockOf('p1'), 0);
    });

    test('un ítem reembolsado no se descuenta', () async {
      final discounted = await service.registerPurchaseDelivery(
        purchase(const [
          PurchaseItem(
            productId: 'p1',
            productName: 'Cera',
            unitPrice: 15000,
            quantity: 1,
            refunded: true,
          ),
        ]),
      );
      expect(discounted.discounted, 0);
      expect(await stockOf('p1'), 5);
    });
  });
}
