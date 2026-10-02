import 'package:barber/theme/app_colors.dart';
import 'package:barber/theme/contrast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Contraste WCAG AA (4.5:1 texto normal) de cada par texto/fondo del sistema
// de color, en claro y en oscuro. Si alguien cambia un token y rompe la
// legibilidad, este test falla.
void main() {
  tearDown(() => AppColors.isDark = false);

  for (final dark in [false, true]) {
    final mode = dark ? 'oscuro' : 'claro';

    group('modo $mode', () {
      setUp(() => AppColors.isDark = dark);

      void expectAA(String name, Color fg, Color bg, [double min = 4.5]) {
        final ratio = contrastRatio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(min),
          reason: '$name: ${ratio.toStringAsFixed(2)}:1 (mínimo $min:1)',
        );
      }

      test('texto principal y secundario sobre fondo y superficie', () {
        expectAA(
          'textPrimary/background',
          AppColors.textPrimary,
          AppColors.background,
        );
        expectAA(
          'textPrimary/surface',
          AppColors.textPrimary,
          AppColors.surface,
        );
        expectAA(
          'textSecondary/background',
          AppColors.textSecondary,
          AppColors.background,
        );
        expectAA(
          'textSecondary/surface',
          AppColors.textSecondary,
          AppColors.surface,
        );
        expectAA(
          'textSecondary/surfaceRaised',
          AppColors.textSecondary,
          AppColors.surfaceRaised,
        );
      });

      test('botón de acción y su texto', () {
        expectAA('onAction/action', AppColors.onAction, AppColors.action, 7);
      });

      test('enlaces y acento sobre el fondo y la superficie', () {
        expectAA('accent/background', AppColors.accent, AppColors.background);
        expectAA('accent/surface', AppColors.accent, AppColors.surface);
      });

      test('texto de estado (badges, íconos) sobre su propio fondo teñido', () {
        for (final entry in {
          'success': AppColors.success,
          'warning': AppColors.warning,
          'error': AppColors.error,
          'accent': AppColors.accent,
          'textSecondary': AppColors.textSecondary,
        }.entries) {
          final bg = blendOver(AppColors.tint(entry.value), AppColors.surface);
          expectAA(
            'readable(${entry.key})',
            AppColors.readable(entry.value),
            bg,
          );
        }
      });

      test('relleno sólido con texto blanco (botón destructivo, avisos)', () {
        for (final entry in {
          'error': AppColors.error,
          'success': AppColors.success,
          'warning': AppColors.warning,
        }.entries) {
          expectAA(
            'onColor/solid(${entry.key})',
            AppColors.onColor,
            AppColors.solid(entry.value),
          );
        }
      });
    });
  }

  test('ensureContrast conserva el matiz y no toca un color que ya cumple', () {
    expect(ensureContrast(Colors.black, Colors.white), Colors.black);
    final fixed = ensureContrast(AppColors.success, Colors.white);
    expect(contrastRatio(fixed, Colors.white), greaterThanOrEqualTo(4.5));
    expect(
      (HSLColor.fromColor(fixed).hue -
              HSLColor.fromColor(AppColors.success).hue)
          .abs(),
      lessThan(2),
    );
  });
}
