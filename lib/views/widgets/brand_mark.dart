import 'package:flutter/material.dart';

/// Ícono de marca: muestra el logo de la app (`lib/views/img/logo.png`).
///
/// Como el archivo es JPEG (sin canal alpha), se presenta directamente
/// con `Image.asset` dentro de un contenedor circular de color primario,
/// de modo que se vea bien sobre cualquier fondo claro u oscuro.
/// La animación de respiración sutil se mantiene cuando [spin] es true.
class BrandMark extends StatefulWidget {
  final double size;

  /// Ignorado: se conserva por compatibilidad con los call-sites existentes,
  /// pero ya no se usa un ColorFilter porque el logo es JPEG (sin alpha).
  final Color? color;
  final bool spin;

  const BrandMark({super.key, this.size = 32, this.color, this.spin = true});

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // El pulso continuo es el único movimiento sin fin de la app: se omite
    // por completo si el sistema pide reducir el movimiento, en vez de
    // solo acortarlo (una preferencia de accesibilidad, no de velocidad).
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (widget.spin && !reduceMotion) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: 1 + (_controller.value * 0.04), child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.22),
        child: Image.asset(
          'lib/views/img/logo.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
