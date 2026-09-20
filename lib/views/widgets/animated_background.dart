import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Fondo decorativo con dos manchas de color difuminadas que flotan
/// lentamente. Se coloca detrás del contenido principal (Stack) para dar
/// profundidad a pantallas que antes eran un color plano — sin afectar el
/// scroll ni la interacción, porque ignora los eventos de puntero.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          return Stack(
            children: [
              Positioned(
                top: -80 + math.sin(t) * 18,
                right: -60 + math.cos(t) * 14,
                child: _Blob(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  size: 220,
                ),
              ),
              Positioned(
                bottom: -70 + math.cos(t) * 16,
                left: -50 + math.sin(t) * 12,
                child: _Blob(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  size: 200,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
