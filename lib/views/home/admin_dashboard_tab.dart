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
      if (dueDate != null && dueDate.isBefore(now) && shop.paymentStatus == PaymentStatus.ok) {
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
    final greetingName = profile?.firstName.isNotEmpty == true ? profile!.firstName : 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $greetingName 👋'),
        actions: [
          if (profile != null)
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Notificaciones',
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotificationsView(uid: profile.uid))),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Panel de administración', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          StreamBuilder<List<AppUser>>(
            stream: userService.watchAll(),
            builder: (context, userSnapshot) {
              final users = userSnapshot.data ?? [];
              return StreamBuilder<List<Barbershop>>(
                stream: barbershopService.watchAll(),
                builder: (context, shopSnapshot) {
                  final shops = shopSnapshot.data ?? [];
                  final activeShops = shops.where((s) => s.active).length;
                  final overdueShops = shops.where((s) => s.paymentStatus != PaymentStatus.ok).length;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.people_outline,
                              value: '${users.length}',
                              label: 'Usuarios registrados',
                              iconColor: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.storefront_outlined,
                              value: '$activeShops',
                              label: 'Barberías activas',
                              iconColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.warning_amber_outlined,
                              value: '$overdueShops',
                              label: 'Barberías con pago pendiente',
                              iconColor: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Acciones rápidas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ActionListTile(
            icon: Icons.people_outline,
            label: 'Gestionar usuarios',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManageUsersView())),
          ),
          const SizedBox(height: 10),
          ActionListTile(
            icon: Icons.storefront_outlined,
            label: 'Ver todas las barberías',
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ManageBarbershopsView(adminControls: true))),
          ),
          const SizedBox(height: 10),
          ActionListTile(
            icon: Icons.settings_outlined,
            label: 'Configuración del sistema',
            onTap: () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('La configuración próximamente'))),
          ),
        ],
      ),
    );
  }
}
