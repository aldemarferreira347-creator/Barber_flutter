import 'dart:async';

import 'package:barber/utils/shared_stream.dart';
import 'package:barber/views/widgets/async_state_view.dart';
import 'package:barber/views/widgets/empty_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

AsyncStateView<List<String>> _view(
  Stream<List<String>> stream, {
  Duration timeout = const Duration(seconds: 15),
}) => AsyncStateView<List<String>>(
  stream: stream,
  timeout: timeout,
  errorTitle: 'No pudimos cargar',
  empty: const EmptyState(
    icon: Icons.inbox_outlined,
    title: 'Todavía no hay nada',
    subtitle: 'Cuando haya algo aparecerá aquí.',
  ),
  builder: (context, items) =>
      Column(children: [for (final i in items) Text(i)]),
);

void main() {
  testWidgets('una lista vacía es un estado vacío, NO un error', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_view(Stream.value(const <String>[]))));
    await tester.pump();

    expect(find.text('Todavía no hay nada'), findsOneWidget);
    expect(find.text('No pudimos cargar'), findsNothing);
  });

  testWidgets('con datos pinta el contenido', (tester) async {
    await tester.pumpWidget(_wrap(_view(Stream.value(const ['uno', 'dos']))));
    await tester.pump();

    expect(find.text('uno'), findsOneWidget);
    expect(find.text('dos'), findsOneWidget);
  });

  testWidgets('permission-denied muestra error de acceso con Reintentar', (
    tester,
  ) async {
    final shared = SharedStreams();
    addTearDown(shared.reset);
    var attempts = 0;
    final stream = shared.of<List<String>>('k', () {
      attempts++;
      if (attempts == 1) {
        return Stream<List<String>>.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
      }
      return Stream.value(const ['ya cargó']);
    });

    await tester.pumpWidget(_wrap(_view(stream)));
    await tester.pump();
    await tester.pump();

    expect(find.text('No pudimos cargar'), findsOneWidget);
    expect(find.textContaining('no tiene acceso'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('ya cargó'), findsOneWidget);
    expect(attempts, 2);

    // La consulta compartida sigue 20 s abierta sin oyentes: se cierra aquí
    // para no dejar el temporizador de gracia pendiente al terminar.
    await tester.pumpWidget(const SizedBox());
    shared.reset();
  });

  testWidgets(
    'una consulta que nunca responde pasa a error, no a spinner eterno',
    (tester) async {
      final never = StreamController<List<String>>();
      addTearDown(never.close);

      await tester.pumpWidget(
        _wrap(_view(never.stream, timeout: const Duration(seconds: 3))),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('No pudimos cargar'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('No pudimos cargar'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('un valor anulable (documento inexistente) cuenta como vacío', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AsyncStateView<String?>(
          stream: Stream<String?>.value(null),
          empty: const Text('no existe'),
          builder: (context, value) => Text(value ?? ''),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('no existe'), findsOneWidget);
  });
}
