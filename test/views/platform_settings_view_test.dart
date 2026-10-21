import 'package:barber/models/platform_settings.dart';
import 'package:barber/repositories/platform_settings_repository.dart';
import 'package:barber/views/admin/platform_settings_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockSettingsRepository extends Mock
    implements PlatformSettingsRepository {}

void main() {
  late MockSettingsRepository repo;

  setUp(() => repo = MockSettingsRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<PlatformSettingsRepository>.value(
        value: repo,
        child: const MaterialApp(home: PlatformSettingsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('primera vez (sin documento): formulario listo, no error', (
    tester,
  ) async {
    when(() => repo.watch())
        .thenAnswer((_) => Stream.value(PlatformSettings.defaults));

    await pump(tester);

    expect(find.textContaining('Aún no has configurado tu Nequi'), findsOne);
    expect(find.text('Nequi de la plataforma'), findsOneWidget);
    expect(find.textContaining('No pudimos'), findsNothing);
  });

  testWidgets('guarda los datos válidos', (tester) async {
    when(() => repo.watch())
        .thenAnswer((_) => Stream.value(PlatformSettings.defaults));
    when(
      () => repo.save(
        nequiPhone: any(named: 'nequiPhone'),
        nequiHolder: any(named: 'nequiHolder'),
        monthlyFee: any(named: 'monthlyFee'),
        graceDays: any(named: 'graceDays'),
      ),
    ).thenAnswer((_) async {});

    await pump(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    verify(
      () => repo.save(
        nequiPhone: '3001234567',
        nequiHolder: '',
        monthlyFee: any(named: 'monthlyFee'),
        graceDays: any(named: 'graceDays'),
      ),
    ).called(1);
  });

  testWidgets('si la lectura falla por permisos lo dice y deja reintentar', (
    tester,
  ) async {
    when(() => repo.watch()).thenAnswer(
      (_) => Stream.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
    );

    await pump(tester);

    expect(find.text('No pudimos cargar la configuración'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
