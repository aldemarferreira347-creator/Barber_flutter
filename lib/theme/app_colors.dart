import 'package:flutter/material.dart';

/// Paleta de la app. Los valores son getters (no const) para poder cambiar
/// entre claro/oscuro en runtime sin tocar los ~40 call sites que ya
/// escriben `AppColors.primary`, `AppColors.surface`, etc. — ver
/// [ThemeController] para quién decide `isDark`.
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
  static Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
  static Color get border =>
      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0);
}
