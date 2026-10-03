import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/scroll_to_top_fab.dart';
import '../widgets/shimmer_box.dart';

class NotificationsView extends StatefulWidget {
  final String uid;

  const NotificationsView({super.key, required this.uid});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _iconFor(NotificationType type) => switch (type) {
    NotificationType.autoPaymentOverdue => Icons.warning_amber_outlined,
    NotificationType.appointmentReminder => Icons.alarm,
    NotificationType.manual => Icons.campaign_outlined,
  };

  Color _colorFor(NotificationType type) => switch (type) {
    NotificationType.autoPaymentOverdue => AppColors.warning,
    NotificationType.appointmentReminder => AppColors.accent,
    NotificationType.manual => AppColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final repo = context.read<NotificationRepository>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      floatingActionButton: ScrollToTopFab(controller: _scrollController),
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.watchForUser(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar las notificaciones'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.notifications_none,
                title: 'Sin notificaciones',
                subtitle: 'Aquí verás los avisos del administrador.',
              ),
            );
          }
          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: AppSpace.lg, bottom: 96),
            children: [
              ResponsiveBody(
                maxWidth: AppLayout.formWidth,
                child: Column(
                  children: [
                    for (final n in notifications) ...[
                      AppCard(
                        onTap: n.read ? null : () => repo.markRead(n.id),
                        semanticLabel: n.read
                            ? null
                            : 'Marcar como leída: ${n.title}',
                        color: n.read
                            ? AppColors.surface
                            : AppColors.tint(AppColors.accent),
                        borderColor: n.read
                            ? AppColors.border
                            : AppColors.accent.withValues(alpha: 0.4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _iconFor(n.type),
                              color: AppColors.readable(_colorFor(n.type)),
                            ),
                            const SizedBox(width: AppSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.title, style: text.titleSmall),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(
                                    n.body,
                                    style: text.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (n.createdAt != null) ...[
                                    const SizedBox(height: AppSpace.sm),
                                    Text(
                                      dateTimeLabel(n.createdAt!),
                                      style: text.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!n.read)
                              Semantics(
                                label: 'No leída',
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    left: AppSpace.sm,
                                    top: AppSpace.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
