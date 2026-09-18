import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/empty_state.dart';

class NotificationsView extends StatelessWidget {
  final String uid;

  const NotificationsView({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<NotificationRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.watchForUser(uid),
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notifications.isEmpty) {
            return const Center(
              child: EmptyState(icon: Icons.notifications_none, title: 'Sin notificaciones', subtitle: 'Aquí verás los avisos del administrador.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (!n.read) repo.markRead(n.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read ? AppColors.surface : AppColors.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: n.read ? AppColors.border : AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        n.type == NotificationType.autoPaymentOverdue ? Icons.warning_amber_outlined : Icons.campaign_outlined,
                        color: n.type == NotificationType.autoPaymentOverdue ? AppColors.warning : AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(n.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
