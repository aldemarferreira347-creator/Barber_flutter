import 'package:flutter/material.dart';

/// Transición de página "premium" (fade + slide + scale sutil) aplicada
/// globalmente vía [ThemeData.pageTransitionsTheme]. Como casi todas las
/// pantallas navegan con `Navigator.push(MaterialPageRoute(...))` en vez de
/// rutas nombradas, este es el único punto que permite cambiar la
/// animación de TODAS las transiciones de la app con un solo archivo.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.04, 0),
            ).animate(secondaryCurved),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Duraciones y curvas reutilizadas por las micro-animaciones de la app,
/// para que todo el sistema comparta el mismo "ritmo" visual.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
  static const curve = Curves.easeOutCubic;
}
