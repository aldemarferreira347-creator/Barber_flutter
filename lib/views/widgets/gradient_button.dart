import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'pressable_scale.dart';

/// Botón primario "premium": relleno con degradado de marca, sombra de
/// color y micro-animación de presión. Reemplaza a `FilledButton` en las
/// llamadas a la acción más importantes (iniciar sesión, registrarse,
/// pagar, confirmar cita).
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return PressableScale(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: enabled
                ? [AppColors.accent, AppColors.primary]
                : [
                    AppColors.textSecondary.withValues(alpha: 0.4),
                    AppColors.textSecondary.withValues(alpha: 0.4),
                  ],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
