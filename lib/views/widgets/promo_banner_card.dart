import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import 'pressable_scale.dart';

/// Tarjeta promocional/motivacional que cierra cada dashboard de rol,
/// siguiendo el mockup de referencia: ícono en círculo, título y subtítulo,
/// sobre un fondo oscuro (opcionalmente con una foto detrás) o un tinte
/// claro del color de acento.
class PromoBannerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool light;
  final String? backgroundImage;
  final VoidCallback? onTap;

  const PromoBannerCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.light = false,
    this.backgroundImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = light ? AppColors.primary : Colors.white;
    final foregroundSecondary = light
        ? AppColors.textSecondary
        : Colors.white.withValues(alpha: 0.75);

    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child:
            Container(
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.accent.withValues(alpha: 0.10)
                        : null,
                    gradient: light
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.isDark
                                ? const [Color(0xFF27272A), Color(0xFF18181B)]
                                : [AppColors.primary, const Color(0xFF1E293B)],
                          ),
                    border: light
                        ? Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2),
                          )
                        : null,
                    image: backgroundImage != null
                        ? DecorationImage(
                            image: AssetImage(backgroundImage!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.55),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: light
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: light ? AppColors.accent : Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: foregroundSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 380.ms)
                .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}
