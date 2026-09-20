import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../appointment/client_appointments_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../help/help_view.dart';
import '../notification/notifications_view.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/promo_banner_card.dart';

class ClientDashboardTab extends StatelessWidget {
  const ClientDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Cliente';
    final appointmentRepo = context.read<AppointmentRepository>();

    return DashboardScaffold(
      greeting: 'Hola, $greetingName 👋',
      subtitle: 'Tu estilo, nuestra prioridad',
      onNotifications: profile == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsView(uid: profile.uid),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ayuda',
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HelpView())),
        child: const Icon(Icons.help_outline),
      ),
      children: [
        PressableScale(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageBarbershopsView(),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('lib/views/img/fondo.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Tu próxima cita está a un clic',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Reservar cita',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 15,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 380.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Barberías destacadas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageBarbershopsView(),
                ),
              ),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        SizedBox(
          height: 132,
          child: StreamBuilder<List<Barbershop>>(
            stream: context.read<BarbershopRepository>().watchAll(),
            builder: (context, snapshot) {
              final shops = (snapshot.data ?? [])
                  .where((s) => s.active)
                  .take(6)
                  .toList();
              if (shops.isEmpty) {
                return Center(
                  child: Text(
                    'Aún no hay barberías activas',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shops.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final shop = shops[index];
                  return PressableScale(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                BarbershopDetailView(barbershopId: shop.id),
                          ),
                        ),
                        child: Container(
                          width: 112,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 56,
                                width: double.infinity,
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
                                        size: 22,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (shop.averageRating > 0)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      shop.averageRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      )
                      .animate(delay: (index * 60).ms)
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Appointment>>(
          stream: profile == null
              ? const Stream<List<Appointment>>.empty()
              : appointmentRepo.watchByClient(profile.uid),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final now = DateTime.now();
            final upcoming = all
                .where(
                  (a) =>
                      a.date.isAfter(now) &&
                      (a.status == AppointmentStatus.pending ||
                          a.status == AppointmentStatus.accepted),
                )
                .toList();
            return ActionListTile(
              icon: Icons.calendar_month_outlined,
              label: 'Tus próximas citas',
              subtitle: upcoming.isEmpty
                  ? 'No tienes citas programadas'
                  : '${upcoming.length} cita(s) programada(s)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClientAppointmentsView(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const PromoBannerCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Tu estilo, nuestra pasión',
          subtitle: 'Encuentra el look perfecto para ti.',
        ),
      ],
    );
  }
}
