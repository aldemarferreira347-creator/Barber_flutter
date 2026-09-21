import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';

/// Estado de error elegante para listas alimentadas por un `StreamBuilder`
/// (`snapshot.hasError`), hermano de [EmptyState] pero con semántica de
/// error: ícono en círculo rojo y, opcionalmente, un botón para reintentar.
/// Los `Stream` de Firestore ya se reconectan solos, así que [onRetry] es
/// opcional — solo tiene sentido cuando la pantalla puede relanzar la
/// consulta explícitamente.
class ErrorState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title = 'Algo salió mal',
    this.subtitle = 'No pudimos cargar esta información. Inténtalo de nuevo.',
    this.onRetry,
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
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 32,
                      color: AppColors.error,
                    ),
                  )
                  .animate()
                  .scaleXY(
                    begin: 0.7,
                    end: 1,
                    duration: 380.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
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
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutCubic);
  }
}
