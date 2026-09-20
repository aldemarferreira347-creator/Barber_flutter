import 'package:flutter/material.dart';

/// Paleta de la app. Los valores son getters (no const) para poder cambiar
/// entre claro/oscuro en runtime sin tocar los ~40 call sites que ya
/// escriben `AppColors.primary`, `AppColors.surface`, etc. — ver
/// [ThemeController] para quién decide `isDark`.
class AppColors {
  AppColors._();

  static bool isDark = false;

  static Color get primary =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A);
  static Color get accent =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static Color get background =>
      isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);
  static Color get surface => isDark ? const Color(0xFF16213A) : Colors.white;
  static Color get textPrimary =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get border =>
      isDark ? const Color(0xFF2A3855) : const Color(0xFFE2E8F0);
}
