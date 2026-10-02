import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Envuelve la app y hace que un cambio de modo claro/oscuro se vea al
/// instante SIN reiniciar la navegación.
///
/// Casi toda la UI lee `AppColors.x` directamente (valores estáticos), así
/// que cambiar `ThemeData` no basta para repintarla. Antes se recreaba toda
/// la app con una `ValueKey`, lo que devolvía al usuario a la pantalla de
/// arranque y le cerraba las pantallas abiertas. Aquí, en cambio, se mantiene
/// el árbol y solo se marcan todos sus elementos para reconstruirse.
class ThemeScope extends StatefulWidget {
  final ThemeController controller;
  final WidgetBuilder builder;

  const ThemeScope({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  State<ThemeScope> createState() => _ThemeScopeState();
}

class _ThemeScopeState extends State<ThemeScope> {
  // Se fija en initState (no como `late`): un `late` se evaluaría en el primer
  // uso, que es justo después del cambio, y nunca vería la diferencia.
  bool _appliedDark = false;

  @override
  void initState() {
    super.initState();
    _appliedDark = widget.controller.isDark;
    widget.controller.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (widget.controller.isDark == _appliedDark) return;
    _appliedDark = widget.controller.isDark;
    // Primero se reconstruye con el ThemeData nuevo y, en cuanto termina ese
    // cuadro, se fuerza el repintado de todo lo que lee AppColors.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rebuildAll(context);
    });
  }

  static void _rebuildAll(BuildContext context) {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
