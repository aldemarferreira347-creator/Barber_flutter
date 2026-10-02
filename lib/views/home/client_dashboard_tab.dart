import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../appointment/client_appointments_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../barbershop/barbershop_catalog_view.dart';
import '../help/help_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/section_header.dart';
import '../widgets/shop_avatar.dart';
import '../widgets/status_badge.dart';

class ClientDashboardTab extends StatelessWidget {
  const ClientDashboardTab({super.key});

  void _openCatalog(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const BarbershopCatalogView()));

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Cliente';

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tu estilo, nuestra prioridad',
      notificationsUid: profile?.uid,
      children: [
        _NextAppointmentCard(
          clientId: profile?.uid,
          onBook: () => _openCatalog(context),
        ),
        const SizedBox(height: AppSpace.xl),
        SectionHeader(
          title: 'Barberías destacadas',
          actionLabel: 'Ver todas',
          onAction: () => _openCatalog(context),
        ),
        const _FeaturedShops(),
        const SizedBox(height: AppSpace.xl),
        const SectionHeader(title: 'Accesos rápidos'),
        ActionListTile(
          icon: Icons.calendar_month_outlined,
          label: 'Mis citas',
          subtitle: 'Próximas, historial y calificaciones',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClientAppointmentsView()),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        ActionListTile(
          icon: Icons.help_outline,
          label: 'Ayuda y soporte',
          subtitle: 'Preguntas frecuentes y contacto',
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HelpView())),
        ),
      ],
    );
  }
}

/// Lo más importante para un cliente: su próxima cita. Si no tiene ninguna,
/// la invitación a reservar.
class _NextAppointmentCard extends StatelessWidget {
  final String? clientId;
  final VoidCallback onBook;

  const _NextAppointmentCard({required this.clientId, required this.onBook});

  static const _upcomingStatuses = {
    AppointmentStatus.pending,
    AppointmentStatus.accepted,
    AppointmentStatus.postponed,
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: clientId == null
          ? const Stream<List<Appointment>>.empty()
          : context.read<AppointmentRepository>().watchByClient(clientId!),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final upcoming =
            (snapshot.data ?? const <Appointment>[])
                .where(
                  (a) =>
                      a.date.isAfter(now) &&
                      _upcomingStatuses.contains(a.status),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));

        if (upcoming.isEmpty) return _BookCard(onBook: onBook);

        final next = upcoming.first;
        final text = Theme.of(context).textTheme;
        return AppCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClientAppointmentsView()),
          ),
          semanticLabel: 'Tu próxima cita, ver mis citas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Tu próxima cita', style: text.labelMedium),
                  ),
                  StatusBadge(
                    label: next.status.label,
                    color: switch (next.status) {
                      AppointmentStatus.accepted => AppColors.success,
                      AppointmentStatus.postponed => AppColors.accent,
                      _ => AppColors.warning,
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(dateTimeLabel(next.date), style: text.headlineSmall),
              const SizedBox(height: AppSpace.xs),
              Text(
                '${next.serviceName} · con ${next.barberName}',
                style: text.secondary,
              ),
              if (upcoming.length > 1) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  '+${upcoming.length - 1} cita(s) más programada(s)',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final VoidCallback onBook;

  const _BookCard({required this.onBook});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reserva tu próxima cita', style: text.titleLarge),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Elige una barbería, un barbero y la hora que mejor te quede.',
            style: text.secondary,
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            expand: false,
            onPressed: onBook,
            icon: Icons.event_available_outlined,
            child: const Text('Reservar cita'),
          ),
        ],
      ),
    );
  }
}

class _FeaturedShops extends StatelessWidget {
  const _FeaturedShops();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 184,
      child: StreamBuilder<List<Barbershop>>(
        stream: context.read<BarbershopRepository>().watchApproved(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se pudieron cargar las barberías',
                textAlign: TextAlign.center,
                style: text.secondary,
              ),
            );
          }
          final shops = [...(snapshot.data ?? const <Barbershop>[])]
            ..sort((a, b) {
              final byRating = b.averageRating.compareTo(a.averageRating);
              return byRating != 0 ? byRating : a.name.compareTo(b.name);
            });
          if (shops.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay barberías activas',
                style: text.secondary,
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: shops.length.clamp(0, 8),
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
            itemBuilder: (context, index) =>
                _FeaturedShopCard(shop: shops[index]),
          );
        },
      ),
    );
  }
}

class _FeaturedShopCard extends StatelessWidget {
  final Barbershop shop;

  const _FeaturedShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 168,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BarbershopDetailView(barbershopId: shop.id),
          ),
        ),
        semanticLabel: 'Barbería ${shop.name}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShopAvatar(photoUrl: shop.photoUrl, name: shop.name, size: 64),
            const SizedBox(height: AppSpace.sm),
            Text(
              shop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            if (shop.address != null && shop.address!.isNotEmpty)
              Text(
                shop.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            const Spacer(),
            if (shop.averageRating > 0)
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: AppColors.gold),
                  const SizedBox(width: 2),
                  Text(
                    shop.averageRating.toStringAsFixed(1),
                    style: text.labelMedium,
                  ),
                ],
              )
            else
              Text('Sin calificaciones', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
