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
import '../widgets/dashboard_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/promo_banner_card.dart';
import '../widgets/status_badge.dart';

class OwnerDashboardTab extends StatelessWidget {
  const OwnerDashboardTab({super.key});

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature próximamente')));
  }

  String _paymentLabel(PaymentStatus status) => switch (status) {
    PaymentStatus.ok => 'Mensualidad al día',
    PaymentStatus.overdue => 'En mora',
    PaymentStatus.blocked => 'Bloqueada',
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

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tu barbería en buenas manos',
      onNotifications: profile == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsView(uid: profile.uid),
              ),
            ),
      children: [
        StreamBuilder<List<Barbershop>>(
          stream: profile == null
              ? const Stream<List<Barbershop>>.empty()
              : barbershopService.watchByOwner(profile.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ErrorState(
                title: 'No pudimos cargar tu barbería',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              );
            }
            final shops = snapshot.data ?? [];
            final approvedShops = shops
                .where(
                  (s) => s.approvalStatus == BarbershopApprovalStatus.approved,
                )
                .toList();
            final shop = approvedShops.isNotEmpty ? approvedShops.first : null;
            final otherShops = shops.where((s) => s.id != shop?.id).toList();
            final barbershopRepo = context.read<BarbershopRepository>();

            if (shop == null) {
              return Column(
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
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          image: shop.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(shop.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: shop.photoUrl == null
                            ? const Icon(Icons.storefront, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((shop.address ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      shop.address!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusBadge.active(shop.active),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ActionListTile(
                  icon: Icons.shield_outlined,
                  label: 'Estado de pago',
                  subtitle: shop.paymentDueDate != null
                      ? 'Vence el ${shop.paymentDueDate!.day}/${shop.paymentDueDate!.month}/${shop.paymentDueDate!.year}'
                      : null,
                  iconColor: _paymentColor(shop.paymentStatus),
                  animationIndex: 0,
                  trailing: shop.paymentStatus == PaymentStatus.ok
                      ? TextButton(
                          onPressed: () => _cancelSubscription(
                            context,
                            barbershopRepo,
                            shop.id,
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : FilledButton(
                          onPressed: () => _paySubscription(
                            context,
                            barbershopRepo,
                            shop.id,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            _paymentLabel(shop.paymentStatus),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                ActionListTile(
                  icon: Icons.info_outline,
                  label: 'Ver información',
                  animationIndex: 1,
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
                  animationIndex: 2,
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
                  animationIndex: 3,
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
                  animationIndex: 4,
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
                  animationIndex: 5,
                  onTap: () => _comingSoon(context, 'Las estadísticas'),
                ),
                const SizedBox(height: 20),
                const PromoBannerCard(
                  light: true,
                  icon: Icons.trending_up,
                  title: 'Haz crecer tu barbería',
                  subtitle:
                      'Revisa tus estadísticas y toma mejores decisiones.',
                ),
                // spec 12.2: un dueño puede tener varias barberías, cada una
                // con su propia aprobación y mensualidad — independientes.
                if (otherShops.isNotEmpty) ...[
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
                  const SizedBox(height: 8),
                  for (final other in otherShops) ...[
                    _OtherShopTile(shop: other),
                    const SizedBox(height: 8),
                  ],
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddBarbershopView(),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Registrar otra barbería'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
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
