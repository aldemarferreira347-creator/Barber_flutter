import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import 'app_button.dart';

/// Estado de error para listas alimentadas por un `StreamBuilder`
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
              color: AppColors.tint(AppColors.error),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              size: 32,
              color: AppColors.readable(AppColors.error),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(subtitle, textAlign: TextAlign.center, style: text.secondary),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(
              onPressed: onRetry,
              icon: Icons.refresh,
              expand: false,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
