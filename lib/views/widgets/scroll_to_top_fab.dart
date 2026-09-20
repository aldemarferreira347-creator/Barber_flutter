import 'package:flutter/material.dart';

/// Botón flotante "volver arriba": aparece solo cuando la lista asociada a
/// [controller] se desplaza más allá de una pantalla, y hace scroll suave
/// de vuelta al inicio.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController controller;

  const ScrollToTopFab({super.key, required this.controller});

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final shouldShow =
        widget.controller.hasClients && widget.controller.offset > 400;
    if (shouldShow != _visible) setState(() => _visible = shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_visible,
        child: FloatingActionButton.small(
          heroTag: null,
          tooltip: 'Volver arriba',
          onPressed: () => widget.controller.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
          child: const Icon(Icons.arrow_upward),
        ),
      ),
    );
  }
}
