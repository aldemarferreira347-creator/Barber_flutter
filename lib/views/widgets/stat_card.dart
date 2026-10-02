import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
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
                  Text(label, style: text.bodyMedium),
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
