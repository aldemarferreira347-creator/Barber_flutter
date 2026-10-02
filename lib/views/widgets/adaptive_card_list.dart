import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'responsive_body.dart';

/// Lista de tarjetas que pasa de una a varias columnas según el ancho
/// disponible. Se construye por filas y de forma perezosa (apta para listas
/// largas); en cada fila las tarjetas toman la altura de la más alta, así no
/// se recorta nada con textos largos ni con letra grande, que es lo que
/// pasa con un `GridView` de proporción fija.
class AdaptiveCardList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double minItemWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 340,
    this.spacing = AppSpace.md,
    this.padding = const EdgeInsets.only(bottom: AppSpace.xxl),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor()
                .clamp(1, 4);
        final rowCount = (itemCount / columns).ceil();
        return ListView.separated(
          padding: padding,
          itemCount: rowCount,
          separatorBuilder: (_, _) => SizedBox(height: spacing),
          itemBuilder: (context, row) {
            final cells = <Widget>[];
            for (var column = 0; column < columns; column++) {
              final index = row * columns + column;
              if (column > 0) cells.add(SizedBox(width: spacing));
              cells.add(
                Expanded(
                  child: index < itemCount
                      ? itemBuilder(context, index)
                      : const SizedBox.shrink(),
                ),
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            );
          },
        );
      },
    );
  }
}

/// Atajo para el cuerpo de una pantalla de lista: centra y limita el ancho.
class AdaptiveListBody extends StatelessWidget {
  final Widget child;

  const AdaptiveListBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(maxWidth: 1100, child: child);
  }
}
