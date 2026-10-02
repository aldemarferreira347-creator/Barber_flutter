import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../barbershop/add_barbershop_view.dart';
import '../barbershop/approval_status_badge.dart';
import '../barbershop/my_barbershops_view.dart';
import '../barbershop/owner_alerts_section.dart';
import '../barbershop/owner_barbershop_manage_view.dart';
import '../notification/notifications_view.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_badge.dart';

/// Inicio del Dueño: resumen de SUS barberías (spec 12.2: cada una con su
/// propia aprobación y mensualidad). La gestión completa de cada una está en
/// "Mis barberías".
class OwnerDashboardTab extends StatelessWidget {
  const OwnerDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final barbershopService = context.read<BarbershopRepository>();
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Dueño';

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tus barberías en buenas manos',
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
                title: 'No pudimos cargar tus barberías',
                subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
              );
            }
            final shops = [...(snapshot.data ?? const <Barbershop>[])]
              ..sort((a, b) => a.name.compareTo(b.name));

            if (shops.isEmpty) {
              return Column(
                children: [
                  const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Aún no tienes barberías',
                    subtitle: 'Registra una pagando la primera mensualidad, o guárdala como borrador.',
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
                OwnerAlertsSection(shops: shops),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mis barberías',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyBarbershopsView(),
                        ),
                      ),
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final shop in shops) ...[
                  _ShopSummaryTile(shop: shop),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ShopSummaryTile extends StatelessWidget {
  final Barbershop shop;

  const _ShopSummaryTile({required this.shop});

  @override
  Widget build(BuildContext context) {
    final approved = shop.approvalStatus == BarbershopApprovalStatus.approved;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OwnerBarbershopManageView(barbershopId: shop.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (shop.paymentDueDate != null && approved)
                    Text(
                      'Vence el ${shop.paymentDueDate!.day}/${shop.paymentDueDate!.month}/${shop.paymentDueDate!.year}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            approved
                ? StatusBadge.active(shop.active)
                : ApprovalStatusBadge(status: shop.approvalStatus),
          ],
        ),
      ),
    );
  }
}
