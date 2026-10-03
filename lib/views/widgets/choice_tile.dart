import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Opción excluyente en forma de tarjeta (servicio, barbero, forma de pago…):
/// borde y marca de selección, sin sombras ni animaciones. Con [enabled]
/// en false se muestra atenuada y no responde.
class ChoiceTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const ChoiceTile({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = enabled && onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: active,
        child: Material(
          color: selected
              ? AppColors.tint(AppColors.action)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: selected ? AppColors.action : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onTap : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: selected
                          ? AppColors.readable(AppColors.action)
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleSmall),
                          if (subtitle != null)
                            Text(subtitle!, style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: AppSpace.sm),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
