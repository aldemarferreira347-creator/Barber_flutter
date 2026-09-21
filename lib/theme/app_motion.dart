import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    // "Reducir movimiento" del sistema (iOS Reduce Motion / Android Remove
    // animations): la navegación es el movimiento más grande e intenso de
    // la app, así que aquí es donde más importa respetarlo — un simple
    // fade corto evita el salto brusco sin el slide/scale que puede
    // resultar incómodo para quienes activaron esa preferencia.
    if (MediaQuery.of(context).disableAnimations) {
      return FadeTransition(opacity: animation, child: child);
    }

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

  /// Sincroniza el motor de animación (`flutter_animate`) con la
  /// preferencia de accesibilidad "reducir movimiento" del sistema.
  ///
  /// Los `.animate()` desperdigados por las vistas casi siempre fijan su
  /// propia duración por efecto, así que esto no los apaga a todos por sí
  /// solo — pero sí es la base para cualquier efecto que no la fije
  /// explícitamente, y evita que la app dependa de un valor por defecto
  /// "normal" cuando el sistema pidió lo contrario. Se llama en cada
  /// build de [BuildContext] raíz (ver `main.dart`), así que reacciona en
  /// vivo si el usuario cambia el ajuste con la app abierta.
  static void syncAccessibility(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Animate.defaultDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
  }
}
