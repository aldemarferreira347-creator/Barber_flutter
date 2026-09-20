import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: AppColors.textSecondary),
                  )
                  .animate()
                  .scaleXY(begin: 0.7, end: 1, duration: 380.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutCubic);
  }
}
