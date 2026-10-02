import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import 'app_card.dart';

/// Tarjeta de métrica: valor grande, etiqueta y un ícono en círculo teñido.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.accent;
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: text.headlineSmall),
                  const SizedBox(height: 2),
                  Text(label, style: text.secondary),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: AppColors.tint(color),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.readable(color), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuadrícula de [StatCard] con filas de altura natural (2 columnas en
/// teléfono, 4 en pantallas anchas): cada fila toma la altura de su tarjeta
/// más alta, así nada se recorta con textos largos o letra grande — algo que
/// un `GridView` de proporción fija no garantiza.
class StatGrid extends StatelessWidget {
  final List<StatCard> children;

  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          final chunk = children.skip(i).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: j < chunk.length
                          ? chunk[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (i + columns < children.length) {
            rows.add(const SizedBox(height: AppSpace.md));
          }
        }
        return Column(children: rows);
      },
    );
  }
}
