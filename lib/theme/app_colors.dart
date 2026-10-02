import 'package:flutter/material.dart';

import 'contrast.dart';

/// Paleta de la app. Los valores son getters (no const) para poder cambiar
/// entre claro/oscuro en runtime sin tocar los ~40 call sites que ya
/// escriben `AppColors.primary`, `AppColors.surface`, etc. — ver
/// [ThemeController] para quién decide `isDark`.
///
/// La paleta base es la del mockup de referencia (negro principal, negro
/// card, gris oscuro, blanco, azul, éxito, alerta, error). Este archivo es
/// el ÚNICO lugar donde viven valores de color: las vistas usan estos
/// tokens, nunca `Color(0x…)` ni `Colors.white/black` sueltos.
class AppColors {
  AppColors._();

  static bool isDark = false;

  static Color get primary =>
      isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A);
  static Color get accent =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  /// Dorado premium de marca — misma paleta que la barbería del mockup.
  /// Se usa como acento cálido puntual (tab activo en modo oscuro,
  /// valoraciones con estrellas), nunca como color de superficie o texto.
  static const gold = Color(0xFFF59E0B);

  // Negro verdadero + gris carbón, igual que el mockup de referencia — nada
  // de grises "zinc" con dominante azulada, que era lo que hacía que el modo
  // oscuro se sintiera como "negro con azul" en vez de un negro premium.
  static Color get background =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF1F5F9);
  static Color get surface => isDark ? const Color(0xFF1A1A1A) : Colors.white;

  /// Superficie elevada sobre [surface] (campos dentro de una tarjeta,
  /// filas seleccionadas, hojas modales).
  static Color get surfaceRaised =>
      isDark ? const Color(0xFF222222) : const Color(0xFFF8FAFC);
  static Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF5E6E85);
  static Color get border =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);

  /// Botón de acción principal: blanco sobre negro en oscuro (como el
  /// mockup) y azul marino sobre claro. [onAction] es el texto/ícono encima.
  static Color get action => isDark ? Colors.white : const Color(0xFF0F172A);
  static Color get onAction => isDark ? Colors.black : Colors.white;

  /// Texto/ícono sobre un relleno sólido de [accent], [primary] o un color
  /// de estado.
  static const onColor = Colors.white;

  /// Relleno sólido de [color] con el que el texto [onColor] (blanco) cumple
  /// contraste AA: oscurece lo justo el verde, el ámbar o el rojo de
  /// estado cuando se usan como fondo de un botón o un aviso.
  static Color solid(Color color) => ensureContrast(color, onColor);

  /// Negro fijo para superficies que NO siguen el tema (p. ej. el fondo de
  /// la pantalla de arranque, que es una foto oscura en ambos modos).
  static const alwaysDark = Color(0xFF000000);

  /// Velo detrás de diálogos y hojas modales.
  static const scrim = Color(0x99000000);

  /// Fondo "teñido" de un color: la base de los badges y de los íconos en
  /// círculo. Sutil sobre la superficie, sin sombras.
  static Color tint(Color color, {double alpha = 0.14}) =>
      color.withValues(alpha: alpha);

  /// Versión de [color] legible como TEXTO o ícono pequeño sobre su propio
  /// fondo teñido ([tint]): se oscurece (claro) o se aclara (oscuro) lo justo
  /// para cumplir contraste AA (4.5:1), conservando el matiz.
  static Color readable(Color color, {double tintAlpha = 0.14}) =>
      ensureContrast(color, blendOver(tint(color, alpha: tintAlpha), surface));
}
