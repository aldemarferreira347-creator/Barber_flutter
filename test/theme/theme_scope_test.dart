import 'package:barber/theme/app_colors.dart';
import 'package:barber/theme/app_theme.dart';
import 'package:barber/theme/theme_controller.dart';
import 'package:barber/theme/theme_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.isDark = false;
  });
  tearDown(() => AppColors.isDark = false);

  testWidgets(
    'cambiar de tema repinta lo que lee AppColors y NO cierra las pantallas abiertas',
    (tester) async {
      final controller = ThemeController();
      await controller.load();

      await tester.pumpWidget(
        ThemeScope(
          controller: controller,
          builder: (context) => MaterialApp(
            theme: AppTheme.current,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          // Lee el color estático, como casi toda la app.
                          body: ColoredBox(
                            key: const Key('panel'),
                            color: AppColors.surface,
                            child: const Text('Pantalla secundaria'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      Color panelColor() =>
          tester.widget<ColoredBox>(find.byKey(const Key('panel'))).color;
      expect(panelColor(), const Color(0xFFFFFFFF));

      await controller.setDark(true);
      await tester.pumpAndSettle();

      expect(
        find.text('Pantalla secundaria'),
        findsOneWidget,
        reason: 'la pantalla abierta sigue ahí',
      );
      expect(
        panelColor(),
        const Color(0xFF1A1A1A),
        reason: 'y se repintó en oscuro',
      );

      await controller.setDark(false);
      await tester.pumpAndSettle();
      expect(panelColor(), const Color(0xFFFFFFFF));
    },
  );
}
