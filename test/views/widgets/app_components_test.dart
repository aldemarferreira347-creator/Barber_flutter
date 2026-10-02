import 'dart:async';

import 'package:barber/theme/app_theme.dart';
import 'package:barber/theme/app_tokens.dart';
import 'package:barber/views/widgets/app_button.dart';
import 'package:barber/views/widgets/app_dialog.dart';
import 'package:barber/views/widgets/empty_state.dart';
import 'package:barber/views/widgets/error_state.dart';
import 'package:barber/views/widgets/responsive_body.dart';
import 'package:barber/views/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Size size = const Size(400, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: AppTheme.current,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('AppButton', () {
    testWidgets(
      'un doble toque ejecuta la acción UNA sola vez (anti doble pago)',
      (tester) async {
        var calls = 0;
        final pending = Completer<void>();
        await tester.pumpWidget(
          _wrap(
            AppButton(
              onPressed: () {
                calls++;
                return pending.future;
              },
              child: const Text('Pagar'),
            ),
          ),
        );

        await tester.tap(find.text('Pagar'));
        await tester.pump();
        await tester.tap(find.text('Pagar'), warnIfMissed: false);
        await tester.pump();

        expect(calls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        pending.complete();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('Pagar'));
        await tester.pump();
        expect(calls, 2, reason: 'vuelve a estar habilitado al terminar');
      },
    );

    testWidgets('si la acción falla, el botón se habilita de nuevo', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          AppButton(
            onPressed: () async {
              calls++;
              throw StateError('sin red');
            },
            child: const Text('Reservar'),
          ),
        ),
      );

      await runZonedGuarded(() async {
        await tester.tap(find.text('Reservar'));
        await tester.pumpAndSettle();
      }, (error, stack) {});

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await runZonedGuarded(() async {
        await tester.tap(find.text('Reservar'));
        await tester.pumpAndSettle();
      }, (error, stack) {});
      expect(calls, 2);
    });

    testWidgets('acción síncrona, null y loading', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(AppButton(onPressed: () => calls++, child: const Text('Ok'))),
      );
      await tester.tap(find.text('Ok'));
      await tester.pump();
      expect(calls, 1);

      await tester.pumpWidget(
        _wrap(const AppButton(onPressed: null, child: Text('Ok'))),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.pumpWidget(
        _wrap(
          AppButton(
            onPressed: () => calls++,
            loading: true,
            child: const Text('Ok'),
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppDialog.confirm', () {
    testWidgets('devuelve true al confirmar y false al cancelar', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await AppDialog.confirm(
                context,
                title: 'Eliminar',
                message: '¿Seguro?',
                confirmLabel: 'Sí, eliminar',
                destructive: true,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('¿Seguro?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('ResponsiveBody', () {
    testWidgets('limita el ancho en escritorio y no recorta en teléfono', (
      tester,
    ) async {
      Future<double> widthFor(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResponsiveBody(child: Container(key: const Key('c'))),
            ),
          ),
        );
        return tester.getSize(find.byKey(const Key('c'))).width;
      }

      addTearDown(tester.view.reset);
      expect(
        await widthFor(const Size(1400, 900)),
        AppLayout.contentWidth - 2 * AppSpace.xxl,
      );
      expect(await widthFor(const Size(360, 700)), 360 - 2 * AppSpace.lg);
    });
  });

  group('estados', () {
    testWidgets('EmptyState muestra su acción y ErrorState su reintento', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              EmptyState(
                icon: Icons.event,
                title: 'Sin citas',
                subtitle: 'Agenda tu primera cita',
                actionLabel: 'Reservar',
                onAction: () => taps++,
              ),
              ErrorState(onRetry: () => taps += 10),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Reservar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(taps, 11);
    });

    testWidgets('StatusBadge muestra su etiqueta', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusBadge(label: 'En mora', color: Colors.orange)),
      );
      expect(find.text('En mora'), findsOneWidget);
    });
  });
}
