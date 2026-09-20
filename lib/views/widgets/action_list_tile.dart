import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import 'pressable_scale.dart';

/// Item de "Acciones rápidas" / menú: icono a la izquierda, texto y chevron.
class ActionListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final int animationIndex;

  const ActionListTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.accent;
    return PressableScale(
          onTap: onTap,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            shadowColor: AppColors.textPrimary.withValues(alpha: 0.08),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            resolvedIconColor.withValues(alpha: 0.20),
                            resolvedIconColor.withValues(alpha: 0.08),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: resolvedIconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing ??
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: (animationIndex * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}
