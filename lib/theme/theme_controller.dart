import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// Dueño de la preferencia de modo oscuro: la persiste y notifica para que
/// [BarberApp] reconstruya todo el árbol (así los widgets que leen
/// `AppColors.x` directamente recogen el valor nuevo).
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'dark_mode';

  bool get isDark => AppColors.isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    AppColors.isDark = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (AppColors.isDark == value) return;
    AppColors.isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
