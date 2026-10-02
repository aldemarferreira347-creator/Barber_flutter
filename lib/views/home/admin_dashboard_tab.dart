import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/app_notification.dart';
import '../../models/app_user.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../admin/manage_users_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../barbershop/payment_insight.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';
import '../widgets/status_badge.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOverduePayments(context);
    });
  }

  /// Aproximación al "chequeo automático de pago vencido" sin backend: se
  /// corre una vez cuando el admin abre su panel, revisa qué barberías ya
  /// pasaron su fecha de vencimiento y las marca 'overdue' + notifica al
  /// dueño. No es un cron real (requeriría Cloud Functions con plan de
  /// pago) pero cubre el caso mientras algún admin use la app.
  Future<void> _checkOverduePayments(BuildContext context) async {
    final barbershopRepo = context.read<BarbershopRepository>();
    final notificationRepo = context.read<NotificationRepository>();
    final shops = await barbershopRepo.watchAll().first;
    final now = DateTime.now();

    for (final shop in shops) {
      final dueDate = shop.paymentDueDate;
      if (dueDate != null &&
          dueDate.isBefore(now) &&
          shop.paymentStatus == PaymentStatus.ok) {
        await barbershopRepo.setPaymentStatus(shop.id, PaymentStatus.overdue);
        await notificationRepo.send(
          toUserId: shop.ownerId,
          title: 'Pago vencido',
          body:
              'El pago de "${shop.name}" venció el ${dueDate.day}/${dueDate.month}/${dueDate.year}. Regulariza para evitar el bloqueo.',
          type: NotificationType.autoPaymentOverdue,
        );
      }
    }
  }

  void _openShops(AdminShopFilter? filter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManageBarbershopsView(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final userService = context.read<UserRepository>();
    final barbershopService = context.read<BarbershopRepository>();
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Admin';

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Panel de administración',
      avatar: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.surface,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: BrandMark(size: 28, spin: false),
        ),
      ),
      notificationsUid: profile?.uid,
      children: [
        StreamBuilder<List<AppUser>>(
          stream: userService.watchAll(),
          builder: (context, userSnapshot) {
            if (userSnapshot.hasError) {
              return const ErrorState(
                title: 'No pudimos cargar las estadísticas',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              );
            }
            final users = userSnapshot.data ?? [];
            return StreamBuilder<List<Barbershop>>(
              stream: barbershopService.watchAll(),
              builder: (context, shopSnapshot) {
                if (shopSnapshot.hasError) {
                  return const ErrorState(
                    title: 'No pudimos cargar las estadísticas',
                    subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
                  );
                }
                final shops = shopSnapshot.data ?? [];
                final pending = shops
                    .where(
                      (s) =>
                          s.approvalStatus == BarbershopApprovalStatus.pending,
                    )
                    .length;
                final late = shops.where((s) {
                  if (s.approvalStatus != BarbershopApprovalStatus.approved) {
                    return false;
                  }
                  final level = paymentInsight(s).level;
                  return level == PaymentInsightLevel.grace ||
                      level == PaymentInsightLevel.graceExpired;
                }).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pending > 0 || late > 0) ...[
                      const SectionHeader(title: 'Requiere tu atención'),
                      if (pending > 0)
                        ActionListTile(
                          icon: Icons.hourglass_top_outlined,
                          iconColor: AppColors.warning,
                          label: 'Solicitudes de barbería',
                          subtitle: 'Esperan tu aprobación o rechazo',
                          trailing: StatusBadge(
                            label: '$pending',
                            color: AppColors.warning,
                          ),
                          onTap: () => _openShops(AdminShopFilter.pending),
                        ),
                      if (pending > 0 && late > 0)
                        const SizedBox(height: AppSpace.sm),
                      if (late > 0)
                        ActionListTile(
                          icon: Icons.payments_outlined,
                          iconColor: AppColors.error,
                          label: 'Mensualidades por regularizar',
                          subtitle: 'En mora o en período de gracia',
                          trailing: StatusBadge(
                            label: '$late',
                            color: AppColors.error,
                          ),
                          onTap: () => _openShops(AdminShopFilter.grace),
                        ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                    const SectionHeader(title: 'Resumen'),
                    StatGrid(
                      children: [
                        StatCard(
                          icon: Icons.storefront_outlined,
                          value: '${shops.length}',
                          label: 'Barberías registradas',
                          iconColor: AppColors.accent,
                        ),
                        StatCard(
                          icon: Icons.people_outline,
                          value: '${users.where((u) => u.active).length}',
                          label: 'Usuarios activos',
                          iconColor: AppColors.success,
                        ),
                        StatCard(
                          icon: Icons.storefront,
                          value: '${shops.where((s) => s.active).length}',
                          label: 'Barberías activas',
                          iconColor: AppColors.accent,
                        ),
                        StatCard(
                          icon: Icons.warning_amber_outlined,
                          value: '${pending + late}',
                          label: 'Pendientes de atención',
                          iconColor: AppColors.warning,
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader(title: 'Acciones rápidas'),
        ActionListTile(
          icon: Icons.people_outline,
          label: 'Gestionar usuarios',
          subtitle: 'Roles, bloqueos y notificaciones',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ManageUsersView())),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.storefront_outlined,
          label: 'Gestión de barberías',
          subtitle: 'Aprobaciones, estado y mensualidad',
          onTap: () => _openShops(null),
        ),
      ],
    );
  }
}
