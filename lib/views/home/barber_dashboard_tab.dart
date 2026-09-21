import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../appointment/barber_appointments_view.dart';
import '../barber/barber_availability_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../notification/notifications_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/error_state.dart';
import '../widgets/promo_banner_card.dart';
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
    final initials = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
              .trim()
              .split(RegExp(r'\s+'))
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tu talento, nuestra prioridad',
      onNotifications: profile == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsView(uid: profile.uid),
              ),
            ),
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
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Barbero',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusBadge(label: 'Activo', color: AppColors.success),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ActionListTile(
          icon: Icons.access_time,
          label: 'Mi horario',
          subtitle: 'Ver y gestionar disponibilidad',
          animationIndex: 0,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BarberAvailabilityView()),
          ),
        ),
        const SizedBox(height: 10),
        ActionListTile(
          icon: Icons.content_cut,
          label: 'Mis servicios',
          subtitle: 'Servicios asignados',
          animationIndex: 1,
          onTap: barbershopId == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageServicesView(barbershopId: barbershopId),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        ActionListTile(
          icon: Icons.bar_chart_outlined,
          label: 'Mis estadísticas',
          subtitle: 'Rendimiento y citas',
          animationIndex: 2,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BarberAppointmentsView()),
          ),
        ),
        if (barbershopId != null) ...[
          const SizedBox(height: 20),
          const Text(
            'Tu barbería',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
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
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BarbershopDetailView(barbershopId: shop.id),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                            ? const Icon(
                                Icons.storefront,
                                color: Colors.white,
                                size: 20,
                              )
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
                            Text(
                              shop.address ?? '',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        const PromoBannerCard(
          icon: Icons.content_cut,
          title: 'La constancia también es talento',
          subtitle: 'Cada corte cuenta.',
          backgroundImage: 'lib/views/img/fondo.png',
        ),
      ],
    );
  }
}
