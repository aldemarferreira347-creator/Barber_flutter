import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../barbershop/add_barbershop_view.dart';
import '../barbershop/approval_status_badge.dart';
import '../barbershop/my_barbershops_view.dart';
import '../barbershop/owner_alerts_section.dart';
import '../barbershop/owner_barbershop_manage_view.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';
import '../widgets/shop_avatar.dart';
import '../widgets/status_badge.dart';

/// Inicio del Dueño: resumen de SUS barberías (spec 12.2: cada una con su
/// propia aprobación y mensualidad) y de la actividad de hoy en cada una. La
/// gestión completa de cada una está en "Mis barberías".
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
      notificationsUid: profile?.uid,
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
              return EmptyState(
                icon: Icons.storefront_outlined,
                title: 'Aún no tienes barberías',
                subtitle: 'Registra una pagando la primera mensualidad, o guárdala como borrador.',
                actionLabel: 'Registrar barbería',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddBarbershopView()),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OwnerAlertsSection(shops: shops),
                SectionHeader(
                  title: 'Mis barberías',
                  actionLabel: 'Ver todas',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyBarbershopsView(),
                    ),
                  ),
                ),
                _ShopsWithActivity(shops: shops),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Las tarjetas de barbería, enriquecidas con la actividad de hoy cuando ya
/// hay barberías aprobadas (las pendientes no tienen citas).
class _ShopsWithActivity extends StatelessWidget {
  final List<Barbershop> shops;

  const _ShopsWithActivity({required this.shops});

  @override
  Widget build(BuildContext context) {
    final approvedIds = [
      for (final s in shops)
        if (s.approvalStatus == BarbershopApprovalStatus.approved) s.id,
    ];
    return StreamBuilder<List<Appointment>>(
      stream: approvedIds.isEmpty
          ? Stream.value(const <Appointment>[])
          : context.read<AppointmentRepository>().watchByBarbershops(
              approvedIds,
            ),
      builder: (context, snapshot) {
        final appointments = snapshot.data ?? const <Appointment>[];
        final now = DateTime.now();
        bool isToday(DateTime d) =>
            d.year == now.year && d.month == now.month && d.day == now.day;

        return Column(
          children: [
            for (final shop in shops) ...[
              _ShopSummaryTile(
                shop: shop,
                todayCount: appointments
                    .where(
                      (a) =>
                          a.barbershopId == shop.id &&
                          isToday(a.date) &&
                          a.status != AppointmentStatus.cancelled &&
                          a.status != AppointmentStatus.rejected,
                    )
                    .length,
                toConfirm: appointments
                    .where(
                      (a) =>
                          a.barbershopId == shop.id &&
                          a.status == AppointmentStatus.pending,
                    )
                    .length,
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ],
        );
      },
    );
  }
}

class _ShopSummaryTile extends StatelessWidget {
  final Barbershop shop;
  final int todayCount;
  final int toConfirm;

  const _ShopSummaryTile({
    required this.shop,
    required this.todayCount,
    required this.toConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final approved = shop.approvalStatus == BarbershopApprovalStatus.approved;
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OwnerBarbershopManageView(barbershopId: shop.id),
        ),
      ),
      semanticLabel: 'Gestionar ${shop.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShopAvatar(photoUrl: shop.photoUrl, name: shop.name),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: text.titleSmall),
                    if (shop.paymentDueDate != null && approved)
                      Text(
                        'Vence el ${shop.paymentDueDate!.day}/${shop.paymentDueDate!.month}/${shop.paymentDueDate!.year}',
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
              approved
                  ? StatusBadge.active(shop.active)
                  : ApprovalStatusBadge(status: shop.approvalStatus),
            ],
          ),
          if (approved) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Icon(
                  Icons.today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  todayCount == 0 ? 'Sin citas hoy' : '$todayCount cita(s) hoy',
                  style: text.bodyMedium,
                ),
                if (toConfirm > 0) ...[
                  const Spacer(),
                  StatusBadge(
                    label: '$toConfirm por confirmar',
                    color: AppColors.warning,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
