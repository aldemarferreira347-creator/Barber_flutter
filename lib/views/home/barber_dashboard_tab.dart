import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../appointment/barber_appointments_view.dart';
import '../barber/barber_availability_view.dart';
import '../barbershop/barbershop_detail_view.dart';
import '../notification/notifications_view.dart';
import '../profile/profile_menu_view.dart';
import '../service/manage_services_view.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';
import 'barber_profile_items.dart';

class BarberDashboardTab extends StatelessWidget {
  const BarberDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final greetingName = profile?.firstName.isNotEmpty == true
        ? profile!.firstName
        : 'Barbero';
    final repo = context.read<AppointmentRepository>();
    final barbershopId = profile?.barbershopId;

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
                Icons.content_cut,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: profile == null
            ? const Stream<List<Appointment>>.empty()
            : repo.watchByBarber(profile.uid),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final now = DateTime.now();
          final todayList =
              all
                  .where(
                    (a) =>
                        a.date.year == now.year &&
                        a.date.month == now.month &&
                        a.date.day == now.day &&
                        (a.status == AppointmentStatus.pending ||
                            a.status == AppointmentStatus.accepted),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, const Color(0xFF1E293B)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hoy',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${todayList.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'citas programadas',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BarberAppointmentsView(),
                        ),
                      ),
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Ver calendario',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        side: const BorderSide(color: Colors.white38),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.person_outline,
                      label: 'Perfil',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileMenuView(
                            items: buildBarberProfileItems(context, profile),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.access_time,
                      label: 'Disponibilidad',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BarberAvailabilityView(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.content_cut,
                      label: 'Servicios',
                      onTap: barbershopId == null
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ManageServicesView(
                                  barbershopId: barbershopId,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              if (barbershopId != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Tu barbería',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                StreamBuilder<Barbershop?>(
                  stream: context.read<BarbershopRepository>().watchOne(
                    barbershopId,
                  ),
                  builder: (context, shopSnapshot) {
                    final shop = shopSnapshot.data;
                    if (shop == null) return const SizedBox.shrink();
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              BarbershopDetailView(barbershopId: shop.id),
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
                                  ? const Icon(
                                      Icons.storefront,
                                      color: Colors.white,
                                      size: 22,
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
                            StatusBadge.active(shop.active),
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Resumen',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.insights_outlined,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Bienvenido! Aquí podrás ver tus citas, clientes y la información de tu barbería.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Mis citas de hoy',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              if (todayList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'No tienes citas programadas',
                    subtitle: 'Cuando un cliente te agende, aparecerá aquí.',
                  ),
                )
              else
                for (final appointment in todayList) ...[
                  AppointmentCard(
                    appointment: appointment,
                    subtitle: 'Cliente: ${appointment.clientName}',
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.surface.withValues(alpha: 0.5)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: onTap == null
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : AppColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onTap == null
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
