import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../notification/notifications_view.dart';
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

  /// Usuario dueño de la bandeja: con él la campana abre sus notificaciones
  /// y muestra un punto de aviso si hay sin leer. Sin uid no hay campana.
  final String? notificationsUid;
  final List<Widget> children;
  final Widget? floatingActionButton;

  const DashboardScaffold({
    super.key,
    required this.greeting,
    required this.subtitle,
    this.avatar,
    this.notificationsUid,
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
                  if (notificationsUid != null)
                    _NotificationsButton(uid: notificationsUid!),
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
  final String uid;

  const _NotificationsButton({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: context.read<NotificationRepository>().watchForUser(uid),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? const <AppNotification>[])
            .where((n) => !n.read)
            .length;
        return IconButton(
          tooltip: unread > 0
              ? 'Notificaciones ($unread sin leer)'
              : 'Notificaciones',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationsView(uid: uid)),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: BorderSide(color: AppColors.border),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            backgroundColor: AppColors.error,
            child: const Icon(Icons.notifications_none, size: 22),
          ),
        );
      },
    );
  }
}
