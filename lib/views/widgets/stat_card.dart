import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final int animationIndex;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.accent;
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: resolvedIconColor.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
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
                child: Icon(icon, color: resolvedIconColor, size: 20),
              ),
            ],
          ),
        )
        .animate(delay: (animationIndex * 80).ms)
        .fadeIn(duration: 320.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
