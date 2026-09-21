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
import '../admin/manage_users_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../notification/notifications_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/brand_mark.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/error_state.dart';
import '../widgets/promo_banner_card.dart';
import '../widgets/stat_card.dart';

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
      avatar: const CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: BrandMark(
            size: 26,
            color: Color(0xFF0F172A),
            spin: false,
          ),
        ),
      ),
      onNotifications: profile == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsView(uid: profile.uid),
              ),
            ),
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
                final overdueShops = shops
                    .where((s) => s.paymentStatus != PaymentStatus.ok)
                    .length;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      icon: Icons.storefront_outlined,
                      value: '${shops.length}',
                      label: 'Barberías registradas',
                      iconColor: AppColors.accent,
                      animationIndex: 0,
                    ),
                    StatCard(
                      icon: Icons.people_outline,
                      value: '${users.length}',
                      label: 'Usuarios activos',
                      iconColor: AppColors.success,
                      animationIndex: 1,
                    ),
                    StatCard(
                      icon: Icons.storefront,
                      value: '${shops.where((s) => s.active).length}',
                      label: 'Barberías activas',
                      iconColor: AppColors.accent,
                      animationIndex: 2,
                    ),
                    StatCard(
                      icon: Icons.warning_amber_outlined,
                      value: '$overdueShops',
                      label: 'Barberías en alerta',
                      iconColor: AppColors.warning,
                      animationIndex: 3,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Acciones rápidas',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ActionListTile(
          icon: Icons.people_outline,
          label: 'Gestionar usuarios',
          animationIndex: 0,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ManageUsersView())),
        ),
        const SizedBox(height: 10),
        ActionListTile(
          icon: Icons.storefront_outlined,
          label: 'Gestión de barberías',
          subtitle: 'Aprobaciones, estado y mensualidad',
          animationIndex: 1,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ManageBarbershopsView(adminControls: true),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const PromoBannerCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Control total',
          subtitle: 'Gestiona todo el sistema desde un solo lugar.',
        ),
      ],
    );
  }
}
