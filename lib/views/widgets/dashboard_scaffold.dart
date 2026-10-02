import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import 'responsive_body.dart';

/// Estructura compartida por los 4 dashboards de rol (Admin/Dueño/Barbero/
/// Cliente): encabezado con saludo, avatar y campana de notificaciones, y
/// debajo el contenido en una sola columna que no se estira en pantallas
/// anchas. Sin degradados ni capas decorativas: el contenido es el
/// protagonista.
class DashboardScaffold extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final Widget? avatar;
  final VoidCallback? onNotifications;

  /// Notificaciones sin leer; si es mayor que 0 se muestra un punto de
  /// aviso sobre la campana.
  final int unreadNotifications;
  final List<Widget> children;
  final Widget? floatingActionButton;

  const DashboardScaffold({
    super.key,
    required this.greeting,
    required this.subtitle,
    this.avatar,
    this.onNotifications,
    this.unreadNotifications = 0,
    required this.children,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        bottom: false,
        child: ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.xxl),
            children: [
              Row(
                children: [
                  if (avatar != null) ...[
                    avatar!,
                    const SizedBox(width: AppSpace.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(greeting, style: text.headlineSmall),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: text.bodyMedium),
                      ],
                    ),
                  ),
                  if (onNotifications != null)
                    _NotificationsButton(
                      onPressed: onNotifications!,
                      unread: unreadNotifications,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int unread;

  const _NotificationsButton({required this.onPressed, required this.unread});

  @override
  Widget build(BuildContext context) {
    final tooltip = unread > 0
        ? 'Notificaciones ($unread sin leer)'
        : 'Notificaciones';
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
      ),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.error,
        smallSize: 8,
        child: const Icon(Icons.notifications_none, size: 22),
      ),
    );
  }
}
