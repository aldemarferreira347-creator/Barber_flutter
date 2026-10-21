import 'package:barber/models/barbershop.dart';
import 'package:barber/models/shop_closure.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/shop_closure_repository.dart';
import 'package:barber/views/barbershop/close_shop_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockShopClosureRepository extends Mock implements ShopClosureRepository {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

/// `pumpAndSettle` no termina mientras un campo de texto tiene el foco (el
/// cursor parpadea sin parar): se avanza un tiempo fijo.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MockShopClosureRepository closures;
  late MockBarbershopRepository shops;

  setUpAll(() {
    registerFallbackValue(DateTime(2026, 1, 5));
  });

  setUp(() {
    closures = MockShopClosureRepository();
    shops = MockBarbershopRepository();
    when(() => shops.watchOne('shop1')).thenAnswer(
      (_) => Stream.value(
        const Barbershop(id: 'shop1', name: 'BarberFlow', ownerId: 'o1'),
      ),
    );
    when(
      () => closures.previewImpact(
        barbershopId: any(named: 'barbershopId'),
        closedFrom: any(named: 'closedFrom'),
        closedUntil: any(named: 'closedUntil'),
      ),
    ).thenAnswer(
      (_) async => const ClosureImpact(
        paidAppointments: 2,
        unpaidAppointments: 1,
        purchases: 1,
      ),
    );
    when(
      () => closures.closeForExternalEvent(
        barbershopId: any(named: 'barbershopId'),
        closedFrom: any(named: 'closedFrom'),
        closedUntil: any(named: 'closedUntil'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer(
      (_) async => const ClosureResult(
        postponed: 2,
        cancelled: 1,
        purchasesNotified: 1,
        notificationsSent: 4,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ShopClosureRepository>.value(value: closures),
          Provider<BarbershopRepository>.value(value: shops),
        ],
        child: const MaterialApp(home: CloseShopView(barbershopId: 'shop1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exige el motivo antes de cerrar', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Confirmar cierre'));
    await settle(tester);

    expect(find.text('Escribe el motivo del cierre.'), findsOneWidget);
    verifyNever(
      () => closures.previewImpact(
        barbershopId: any(named: 'barbershopId'),
        closedFrom: any(named: 'closedFrom'),
        closedUntil: any(named: 'closedUntil'),
      ),
    );
  });

  testWidgets('sin fecha de regreso pide confirmar y "No" no cierra nada', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Remodelación');
    await tester.tap(find.text('Confirmar cierre'));
    await settle(tester);

    expect(find.text('¿Cerrar hasta nuevo aviso?'), findsOneWidget);
    expect(find.textContaining('hasta que tú la reabras'), findsOneWidget);
    expect(find.textContaining('2 cita(s) pagada(s)'), findsOneWidget);

    await tester.tap(find.text('No, elegir una fecha'));
    await settle(tester);

    verifyNever(
      () => closures.closeForExternalEvent(
        barbershopId: any(named: 'barbershopId'),
        closedFrom: any(named: 'closedFrom'),
        closedUntil: any(named: 'closedUntil'),
        reason: any(named: 'reason'),
      ),
    );
    expect(find.text('Hasta: sin fecha de regreso'), findsOneWidget);
  });

  testWidgets(
    'sin fecha de regreso y confirmando "Sí" cierra sin fecha final',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'Remodelación');
      await tester.tap(find.text('Confirmar cierre'));
      await settle(tester);
      await tester.tap(find.text('Sí, cerrar hasta nuevo aviso'));
      await settle(tester);

      final captured = verify(
        () => closures.closeForExternalEvent(
          barbershopId: 'shop1',
          closedFrom: any(named: 'closedFrom'),
          closedUntil: captureAny(named: 'closedUntil'),
          reason: 'Remodelación',
        ),
      ).captured;
      expect(captured.single, isNull);
      expect(find.text('La barbería quedó cerrada.'), findsOneWidget);
      expect(find.textContaining('Se avisó a 4 cliente(s)'), findsOneWidget);
    },
  );

  testWidgets('si la barbería ya está cerrada se ofrece reabrirla', (
    tester,
  ) async {
    when(() => shops.watchOne('shop1')).thenAnswer(
      (_) => Stream.value(
        Barbershop(
          id: 'shop1',
          name: 'BarberFlow',
          ownerId: 'o1',
          closure: ShopClosure(
            id: 'c1',
            from: DateTime.now().subtract(const Duration(hours: 2)),
            reason: 'Remodelación',
          ),
        ),
      ),
    );
    when(() => closures.reopen('shop1')).thenAnswer((_) async {});

    await pump(tester);

    expect(find.text('Barbería cerrada'), findsOneWidget);
    expect(find.textContaining('hasta nuevo aviso'), findsWidgets);
    expect(find.text('Confirmar cierre'), findsNothing);

    await tester.tap(find.text('Reabrir barbería'));
    await settle(tester);
    await tester.tap(find.text('Sí, reabrir'));
    await settle(tester);

    verify(() => closures.reopen('shop1')).called(1);
  });

  test('closureImpactText describe cada efecto', () {
    expect(
      closureImpactText(const ClosureImpact()),
      contains('no hay citas ni compras'),
    );
    final text = closureImpactText(
      const ClosureImpact(
        paidAppointments: 1,
        unpaidAppointments: 2,
        purchases: 3,
      ),
    );
    expect(text, contains('1 cita(s) pagada(s) quedarán aplazadas'));
    expect(text, contains('2 cita(s) sin pago se cancelarán'));
    expect(text, contains('3 compra(s)'));
  });

  test('Timestamp en el mapa del cierre se lee de vuelta', () {
    final closure = ShopClosure.fromMap({
      'closureId': 'c',
      'from': Timestamp.fromDate(DateTime(2026, 1, 5, 8)),
      'until': null,
      'reason': 'x',
    });
    expect(closure!.isIndefinite, true);
    expect(closure.isActiveAt(DateTime(2026, 1, 6)), true);
    expect(closure.isActiveAt(DateTime(2026, 1, 4)), false);
  });
}
