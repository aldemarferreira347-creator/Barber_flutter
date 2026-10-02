import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum AppButtonVariant {
  /// Acción principal de la pantalla (una por pantalla).
  primary,

  /// Acción alternativa, con borde.
  secondary,

  /// Acción destructiva o irreversible (eliminar, cancelar membresía).
  destructive,

  /// Acción de baja jerarquía, sin relleno.
  text,
}

/// Botón único de la app. Reemplaza al antiguo botón con degradado y a los
/// `FilledButton`/`OutlinedButton` sueltos en las acciones que escriben
/// datos o cuestan dinero.
///
/// Si [onPressed] devuelve un `Future`, el botón se deshabilita y muestra un
/// indicador de progreso hasta que termine: así un doble toque nunca
/// duplica un pago, una reserva o una aprobación. Con [loading] se puede
/// forzar ese estado desde fuera (p. ej. un `AuthController.isBusy`).
class AppButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final IconData? icon;

  /// Widget al inicio (p. ej. el logo de Google); se usa en lugar de [icon].
  final Widget? leading;
  final AppButtonVariant variant;
  final bool loading;

  /// Ocupa todo el ancho disponible (por defecto). Con `false` se ajusta al
  /// contenido.
  final bool expand;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.leading,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _running = false;

  bool get _busy => _running || widget.loading;

  Future<void> _handlePressed() async {
    if (_busy) return;
    final result = widget.onPressed?.call();
    if (result is! Future) return;
    setState(() => _running = true);
    try {
      await result;
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Color get _foreground => switch (widget.variant) {
    AppButtonVariant.primary => AppColors.onAction,
    AppButtonVariant.destructive => AppColors.onColor,
    AppButtonVariant.secondary => AppColors.textPrimary,
    AppButtonVariant.text => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !_busy;
    final callback = enabled ? _handlePressed : null;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(child: widget.child),
      ],
    );

    // El texto se conserva (invisible) mientras carga para que el botón no
    // cambie de ancho; el indicador se dibuja encima.
    final content = Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: _busy ? 0 : 1, child: label),
        if (_busy)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: _foreground,
            ),
          ),
      ],
    );

    final size = widget.expand ? const Size.fromHeight(52) : const Size(0, 52);

    final button = switch (widget.variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        style: FilledButton.styleFrom(minimumSize: size),
        child: content,
      ),
      AppButtonVariant.destructive => FilledButton(
        onPressed: callback,
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: AppColors.solid(AppColors.error),
          foregroundColor: AppColors.onColor,
        ),
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: callback,
        style: OutlinedButton.styleFrom(minimumSize: size),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: callback,
        style: TextButton.styleFrom(minimumSize: Size(size.width, 48)),
        child: content,
      ),
    };

    return button;
  }
}
