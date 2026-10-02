import 'package:barber/models/barbershop.dart';
import 'package:barber/models/day_schedule.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/theme/app_theme.dart';
import 'package:barber/views/barbershop/barbershop_catalog_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

Barbershop _shop(
  String id,
  String name, {
  String? address,
  bool open = true,
  int stars = 0,
}) => Barbershop(
  id: id,
  ownerId: 'o',
  name: name,
  address: address,
  active: true,
  approvalStatus: BarbershopApprovalStatus.approved,
  ratingSum: stars,
  ratingCount: stars > 0 ? 1 : 0,
  schedule: {
    for (final day in kWeekdays)
      day: DaySchedule(isOpen: open, openTime: '00:00', closeTime: '23:59'),
  },
);

void main() {
  late MockBarbershopRepository repo;

  Widget wrap() => Provider<BarbershopRepository>.value(
    value: repo,
    child: MaterialApp(
      theme: AppTheme.current,
      home: const BarbershopCatalogView(),
    ),
  );

  setUp(() => repo = MockBarbershopRepository());

  testWidgets('lista las barberías aprobadas con su valoración', (
    tester,
  ) async {
    when(() => repo.watchApproved()).thenAnswer(
      (_) => Stream.value([
        _shop('s1', 'Barbería Central', address: 'Calle 1', stars: 4),
        _shop('s2', 'Barbería Norte', address: 'Calle 2'),
      ]),
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Barbería Central'), findsOneWidget);
    expect(find.text('Barbería Norte'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('Abierta · cierra 23:59'), findsNWidgets(2));
  });

  testWidgets(
    'busca por nombre o dirección y explica cuando no hay resultados',
    (tester) async {
      when(() => repo.watchApproved()).thenAnswer(
        (_) => Stream.value([
          _shop('s1', 'Barbería Central', address: 'Calle 1'),
          _shop('s2', 'Barbería Norte', address: 'Avenida 9'),
        ]),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'avenida');
      await tester.pumpAndSettle();
      expect(find.text('Barbería Norte'), findsOneWidget);
      expect(find.text('Barbería Central'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No encontramos barberías'), findsOneWidget);
    },
  );

  testWidgets('el filtro "Abiertas ahora" oculta las cerradas', (tester) async {
    when(() => repo.watchApproved()).thenAnswer(
      (_) => Stream.value([
        _shop('s1', 'Abierta SA'),
        _shop('s2', 'Cerrada SA', open: false),
      ]),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Cerrada SA'), findsOneWidget);

    await tester.tap(find.text('Abiertas ahora'));
    await tester.pumpAndSettle();
    expect(find.text('Abierta SA'), findsOneWidget);
    expect(find.text('Cerrada SA'), findsNothing);
  });

  testWidgets('"Mejor valoradas" las ordena por calificación', (tester) async {
    when(() => repo.watchApproved()).thenAnswer(
      (_) => Stream.value([
        _shop('s1', 'Aaa', stars: 3),
        _shop('s2', 'Bbb', stars: 5),
      ]),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mejor valoradas'));
    await tester.pumpAndSettle();

    // En el ancho de prueba hay 2 columnas: el primero queda a la izquierda.
    final first = tester.getTopLeft(find.text('Bbb'));
    final second = tester.getTopLeft(find.text('Aaa'));
    expect(first.dy, second.dy);
    expect(first.dx, lessThan(second.dx));
  });

  testWidgets('un error de carga muestra el estado de error', (tester) async {
    when(
      () => repo.watchApproved(),
    ).thenAnswer((_) => Stream<List<Barbershop>>.error(StateError('sin red')));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar las barberías'), findsOneWidget);
  });
}
