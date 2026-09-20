import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../barber/manage_barbers_view.dart';
import '../barbershop/add_barbershop_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../barbershop/edit_schedule_view.dart';
import '../notification/notifications_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class OwnerDashboardTab extends StatelessWidget {
  const OwnerDashboardTab({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  String _paymentLabel(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => 'Mensualidad al día',
    PaymentStatus.overdue => 'Mensualidad vencida (en gracia)',
    PaymentStatus.blocked => 'Bloqueada por mensualidad',
  };

  Color _paymentColor(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => AppColors.success,
    PaymentStatus.overdue => AppColors.warning,
    PaymentStatus.blocked => AppColors.error,
  };

  Future<void> _cancelSubscription(
    BuildContext context,
    BarbershopRepository repo,
    String shopId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar membresía'),
        content: const Text(
          'Tu barbería se bloqueará de inmediato, sin período de gracia. Las citas ya pagadas dentro del período vigente no se ven afectadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await repo.cancelSubscription(shopId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      }
    }
  }

  Future<void> _paySubscription(
    BuildContext context,
    BarbershopRepository repo,
    String shopId,
  ) async {
    try {
      await repo.paySubscription(shopId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pago solicitado. Confírmalo desde tu app Nequi.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar el pago: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Dueño';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, $greetingName 👋'),
        actions: [
          if (profile != null)
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Notificaciones',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsView(uid: profile.uid),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.storefront_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Barbershop>>(
        stream: profile == null
            ? const Stream<List<Barbershop>>.empty()
            : barbershopService.watchByOwner(profile.uid),
        builder: (context, snapshot) {
          final shops = snapshot.data ?? [];
          final approvedShops = shops
              .where(
                (s) => s.approvalStatus == BarbershopApprovalStatus.approved,
              )
              .toList();
          final shop = approvedShops.isNotEmpty ? approvedShops.first : null;
          final otherShops = shops.where((s) => s.id != shop?.id).toList();
          final barbershopRepo = context.read<BarbershopRepository>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tu barbería en buenas manos',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (shop == null)
                Column(
                  children: [
                    const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Aún no tienes una barbería',
                      subtitle: 'Registra los datos básicos para empezar a gestionarla.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddBarbershopView(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar barbería'),
                    ),
                  ],
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mi barbería',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              shop.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge.active(shop.active),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _paymentColor(shop.paymentStatus)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _paymentColor(shop.paymentStatus)
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _paymentLabel(shop.paymentStatus),
                          style: TextStyle(
                            color: _paymentColor(shop.paymentStatus),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (shop.paymentStatus == PaymentStatus.ok)
                        TextButton(
                          onPressed: () => _cancelSubscription(
                            context,
                            barbershopRepo,
                            shop.id,
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(color: AppColors.error),
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: () => _paySubscription(
                            context,
                            barbershopRepo,
                            shop.id,
                          ),
                          child: const Text('Pagar mensualidad'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ActionListTile(
                  icon: Icons.info_outline,
                  label: 'Ver información',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          BarbershopDetailView(barbershopId: shop.id),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.content_cut,
                  label: 'Gestionar barberos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageBarbersView(barbershopId: shop.id),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.design_services_outlined,
                  label: 'Gestionar servicios',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ManageServicesView(
                        barbershopId: shop.id,
                        canManage: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.schedule_outlined,
                  label: 'Horarios de atención',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditScheduleView(
                        barbershopId: shop.id,
                        initialSchedule: shop.schedule,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.bar_chart_outlined,
                  label: 'Ver estadísticas',
                  onTap: () => _comingSoon(context, 'Las estadísticas'),
                ),
                // spec 12.2: un dueño puede tener varias barberías, cada una
                // con su propia aprobación y mensualidad — independientes.
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tus barberías',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddBarbershopView(),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Otra barbería'),
                    ),
                  ],
                ),
                if (otherShops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final other in otherShops) ...[
                    _OtherShopTile(shop: other),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OtherShopTile extends StatelessWidget {
  final Barbershop shop;

  const _OtherShopTile({required this.shop});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (shop.approvalStatus) {
      BarbershopApprovalStatus.pending => (
        'Pendiente de revisión',
        AppColors.warning,
      ),
      BarbershopApprovalStatus.approved => ('Aprobada', AppColors.success),
      BarbershopApprovalStatus.rejected => ('Rechazada', AppColors.error),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BarbershopDetailView(barbershopId: shop.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shop.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
