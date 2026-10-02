import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'app_button.dart';

/// Estado vacío: qué falta y, si hay una acción obvia, cómo resolverlo.
/// Pasa [actionLabel] + [onAction] cuando el usuario puede hacer algo al
/// respecto (agendar una cita, crear un servicio…): un estado vacío sin
/// salida es un callejón sin salida.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpace.xl,
        horizontal: AppSpace.lg,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.lg),
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.textSecondary, alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(subtitle, textAlign: TextAlign.center, style: text.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(
              onPressed: onAction,
              expand: false,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
