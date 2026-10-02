import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../appointment/barber_appointments_view.dart';
import '../barber/barber_availability_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/error_state.dart';
import '../widgets/section_header.dart';
import '../widgets/shop_avatar.dart';
import '../widgets/status_badge.dart';

class BarberDashboardTab extends StatelessWidget {
  const BarberDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Barbero';
    final barbershopId = profile?.barbershopId;

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tu talento, nuestra prioridad',
      notificationsUid: profile?.uid,
      children: [
        _TodayCard(barberId: profile?.uid),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader(title: 'Mi trabajo'),
        ActionListTile(
          icon: Icons.event_note_outlined,
          label: 'Mi agenda',
          subtitle: 'Todas tus citas: confirmar, completar o posponer',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BarberAppointmentsView()),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.access_time,
          label: 'Mi disponibilidad',
          subtitle: 'Marca tu salida o tu regreso de la tienda',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BarberAvailabilityView()),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.content_cut,
          label: 'Servicios de la barbería',
          subtitle: 'Consulta el catálogo y sus precios',
          onTap: barbershopId == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageServicesView(barbershopId: barbershopId),
                  ),
                ),
        ),
        if (barbershopId != null) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionHeader(title: 'Tu barbería'),
          StreamBuilder<Barbershop?>(
            stream: context.read<BarbershopRepository>().watchOne(barbershopId),
            builder: (context, shopSnapshot) {
              if (shopSnapshot.hasError) {
                return const ErrorState(
                  title: 'No se pudo cargar tu barbería',
                  subtitle: 'Verifica tu conexión e inténtalo de nuevo.',
                );
              }
              final shop = shopSnapshot.data;
              if (shop == null) return const SizedBox.shrink();
              final text = Theme.of(context).textTheme;
              return AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BarbershopDetailView(barbershopId: shop.id),
                  ),
                ),
                semanticLabel: 'Ver ${shop.name}',
                child: Row(
                  children: [
                    ShopAvatar(photoUrl: shop.photoUrl, name: shop.name),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shop.name, style: text.titleSmall),
                          if (shop.address != null)
                            Text(shop.address!, style: text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// El resumen del día del barbero: cuántas citas tiene hoy, cuál es la
/// siguiente y cuántas esperan que las confirme.
class _TodayCard extends StatelessWidget {
  final String? barberId;

  const _TodayCard({required this.barberId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: barberId == null
          ? const Stream<List<Appointment>>.empty()
          : context.read<AppointmentRepository>().watchByBarber(barberId!),
      builder: (context, snapshot) {
        final now = DateTime.now();
        bool isToday(DateTime d) =>
            d.year == now.year && d.month == now.month && d.day == now.day;
        final all = snapshot.data ?? const <Appointment>[];
        final today =
            all
                .where(
                  (a) =>
                      isToday(a.date) &&
                      a.status != AppointmentStatus.cancelled &&
                      a.status != AppointmentStatus.rejected,
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        final next = today
            .where(
              (a) =>
                  a.date.isAfter(now) &&
                  (a.status == AppointmentStatus.pending ||
                      a.status == AppointmentStatus.accepted),
            )
            .firstOrNull;
        final toConfirm = all
            .where((a) => a.status == AppointmentStatus.pending)
            .length;
        final text = Theme.of(context).textTheme;

        return AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BarberAppointmentsView()),
          ),
          semanticLabel: 'Resumen de hoy, abrir mi agenda',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Hoy', style: text.labelMedium)),
                  if (toConfirm > 0)
                    StatusBadge(
                      label: '$toConfirm por confirmar',
                      color: AppColors.warning,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                today.isEmpty ? 'Sin citas hoy' : '${today.length} cita(s) hoy',
                style: text.headlineSmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                next == null
                    ? (today.isEmpty
                          ? 'Aprovecha para revisar tu agenda de los próximos días.'
                          : 'No quedan más citas por atender hoy.')
                    : 'Siguiente: ${timeLabel(next.date)} · ${next.clientName} · ${next.serviceName}',
                style: text.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}
