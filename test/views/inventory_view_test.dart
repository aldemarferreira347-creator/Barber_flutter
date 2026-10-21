import 'package:barber/models/product.dart';
import 'package:barber/models/stock_movement.dart';
import 'package:barber/repositories/inventory_repository.dart';
import 'package:barber/repositories/product_repository.dart';
import 'package:barber/views/product/inventory_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockProductRepository extends Mock implements ProductRepository {}

class MockInventoryRepository extends Mock implements InventoryRepository {}

void main() {
  late MockProductRepository products;
  late MockInventoryRepository inventory;

  setUpAll(() {
    registerFallbackValue(StockMovementType.inbound);
    registerFallbackValue(StockReason.restock);
  });

  setUp(() {
    products = MockProductRepository();
    inventory = MockInventoryRepository();
    when(() => inventory.watchMovements('shop1')).thenAnswer(
      (_) => Stream.value(const <StockMovement>[]),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductRepository>.value(value: products),
          Provider<InventoryRepository>.value(value: inventory),
        ],
        child: const MaterialApp(home: InventoryView(barbershopId: 'shop1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  const stocked = Product(
    id: 'p1',
    barbershopId: 'shop1',
    name: 'Cera',
    price: 15000,
    stock: 5,
  );
  const untracked = Product(
    id: 'p2',
    barbershopId: 'shop1',
    name: 'Gel',
    price: 9000,
  );

  testWidgets('sin productos explica qué pasará, no muestra error', (
    tester,
  ) async {
    when(
      () => products.watchByBarbershop('shop1'),
    ).thenAnswer((_) => Stream.value(const <Product>[]));

    await pump(tester);

    expect(find.text('Aún no hay productos'), findsOneWidget);
    expect(find.textContaining('No pudimos'), findsNothing);
  });

  testWidgets('muestra las existencias y bloquea la salida sin inventario', (
    tester,
  ) async {
    when(
      () => products.watchByBarbershop('shop1'),
    ).thenAnswer((_) => Stream.value(const [stocked, untracked]));

    await pump(tester);

    expect(find.text('5 unidades'), findsOneWidget);
    expect(find.text('Sin inventario'), findsOneWidget);
    final exits = find.widgetWithText(OutlinedButton, 'Salida');
    expect(tester.widget<OutlinedButton>(exits.at(0)).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(exits.at(1)).onPressed, isNull);
  });

  testWidgets('registra una salida con su motivo', (tester) async {
    when(
      () => products.watchByBarbershop('shop1'),
    ).thenAnswer((_) => Stream.value(const [stocked]));
    when(
      () => inventory.registerMovement(
        barbershopId: any(named: 'barbershopId'),
        productId: any(named: 'productId'),
        type: any(named: 'type'),
        quantity: any(named: 'quantity'),
        reason: any(named: 'reason'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});

    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salida'));
    // El campo de cantidad tiene el foco (cursor parpadeando): no "se asienta".
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // No se puede sacar más de lo que hay.
    await tester.enterText(find.byType(TextFormField).first, '9');
    await tester.tap(find.text('Registrar salida'));
    await tester.pump();
    expect(find.text('Solo hay 5'), findsOneWidget);
    verifyNever(
      () => inventory.registerMovement(
        barbershopId: any(named: 'barbershopId'),
        productId: any(named: 'productId'),
        type: any(named: 'type'),
        quantity: any(named: 'quantity'),
        reason: any(named: 'reason'),
        note: any(named: 'note'),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '2');
    await tester.tap(find.text('Pérdida o daño'));
    await tester.tap(find.text('Registrar salida'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(
      () => inventory.registerMovement(
        barbershopId: 'shop1',
        productId: 'p1',
        type: StockMovementType.outbound,
        quantity: 2,
        reason: StockReason.waste,
        note: '',
      ),
    ).called(1);
  });

  testWidgets('la pestaña de movimientos muestra quién movió qué', (
    tester,
  ) async {
    when(
      () => products.watchByBarbershop('shop1'),
    ).thenAnswer((_) => Stream.value(const <Product>[]));
    when(() => inventory.watchMovements('shop1')).thenAnswer(
      (_) => Stream.value([
        StockMovement(
          id: 'm1',
          barbershopId: 'shop1',
          productId: 'p1',
          productName: 'Cera',
          type: StockMovementType.outbound,
          quantity: 2,
          reason: StockReason.sale,
          previousStock: 5,
          stockAfter: 3,
          byUserId: 'b1',
          byUserName: 'Beto',
          createdAt: DateTime(2026, 10, 1, 10),
        ),
      ]),
    );

    await pump(tester);
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();

    expect(find.text('Cera'), findsOneWidget);
    expect(find.textContaining('Beto'), findsOneWidget);
    expect(find.text('-2'), findsOneWidget);
    expect(find.text('quedan 3'), findsOneWidget);
  });
}
