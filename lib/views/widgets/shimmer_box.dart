import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';

/// Rectángulo con animación shimmer, usado como esqueleto de carga en listas
/// que dependen de un `StreamBuilder` (evita el salto brusco de "spinner
/// centrado" a contenido y hace la espera sentirse premium).
class ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadiusGeometry borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surface,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Lista de esqueletos, para simular varias tarjetas cargando a la vez.
/// Si el espacio vertical es acotado muestra solo los que caben (nunca
/// desborda en pantallas bajas); si no, muestra [count].
class ShimmerList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ShimmerList({super.key, this.count = 3, this.itemHeight = 78});

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var visible = count;
        if (constraints.hasBoundedHeight) {
          final fit = ((constraints.maxHeight + _gap) / (itemHeight + _gap))
              .floor();
          visible = fit.clamp(1, count);
        }
        return Column(
          children: [
            for (var i = 0; i < visible; i++) ...[
              ShimmerBox(height: itemHeight),
              if (i != visible - 1) const SizedBox(height: _gap),
            ],
          ],
        );
      },
    );
  }
}
