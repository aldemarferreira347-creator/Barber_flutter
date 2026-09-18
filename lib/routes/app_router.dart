import 'package:flutter/material.dart';

import '../views/splash/splash_view.dart';

class AppRoutes {
  static const String root = '/';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
      default:
        return MaterialPageRoute(builder: (_) => const SplashView());
    }
  }
}
