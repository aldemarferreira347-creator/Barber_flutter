import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Ícono de marca: el logo real entregado por el cliente (silueta de un
/// caballero con barba + tijeras, `lib/views/img/logo.png`). Es blanco sobre
/// fondo transparente, así que se re-tiñe con [ColorFilter] para adaptarse a
/// cada pantalla (blanco sobre fondo oscuro, azul marino sobre fondo claro)
/// reutilizando los tokens existentes de [AppColors] — no introduce colores
/// nuevos. Respira suavemente para que el logo nunca se sienta estático.
class BrandMark extends StatefulWidget {
  final double size;
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
    if (widget.spin) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Transform.scale(scale: 1 + (_controller.value * 0.04), child: child),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        child: Image.asset(
          'lib/views/img/logo.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
