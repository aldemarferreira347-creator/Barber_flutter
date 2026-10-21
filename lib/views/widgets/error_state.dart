import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/failure.dart';
import 'app_button.dart';

/// Estado de error para listas alimentadas por un `StreamBuilder`
/// (`snapshot.hasError`), hermano de [EmptyState] pero con semántica de
/// error: ícono en círculo rojo y, opcionalmente, un botón para reintentar.
/// Los `Stream` de Firestore ya se reconectan solos, así que [onRetry] es
/// opcional — solo tiene sentido cuando la pantalla puede relanzar la
/// consulta explícitamente.
class ErrorState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  /// El error que originó este estado. Con él, el texto y el ícono dicen qué
  /// pasó de verdad (sin conexión, sin permiso...) en lugar de un genérico.
  final Object? error;

  const ErrorState({
    super.key,
    this.title = 'Algo salió mal',
    this.subtitle,
    this.onRetry,
    this.error,
  });

  FailureKind get _kind =>
      error == null ? FailureKind.unknown : classifyFailure(error!);

  String get _subtitle {
    if (subtitle != null) return subtitle!;
    return switch (_kind) {
      FailureKind.network =>
        'No hay conexión con el servidor. Revisa tu internet e inténtalo '
            'de nuevo.',
      FailureKind.access =>
        'Tu sesión no tiene acceso a esta información. Cierra sesión y '
            'vuelve a entrar; si sigue igual, avisa al administrador.',
      FailureKind.config =>
        'Estamos terminando de configurar el servicio. Inténtalo de nuevo '
            'en unos minutos.',
      FailureKind.unknown =>
        'No pudimos cargar esta información. Inténtalo de nuevo.',
    };
  }

  /// Código corto del error, para que quien lo reporte (o quien da soporte)
  /// sepa qué falló de verdad sin abrir los registros del teléfono.
  String? get _technicalCode {
    final e = error;
    if (e == null) return null;
    if (e is LoadTimeoutException) return 'tiempo-agotado';
    return failureCode(e) ?? e.runtimeType.toString();
  }

  IconData get _icon => switch (_kind) {
    FailureKind.network => Icons.wifi_off_outlined,
    FailureKind.access => Icons.lock_outline,
    _ => Icons.error_outline,
  };

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
              _icon,
              size: 32,
              color: AppColors.readable(AppColors.error),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          Text(_subtitle, textAlign: TextAlign.center, style: text.secondary),
          if (_technicalCode != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'Código: $_technicalCode',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
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
