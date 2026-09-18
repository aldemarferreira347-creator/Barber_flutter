import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';

class ClientDashboardTab extends StatelessWidget {
  const ClientDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final greetingName = profile?.firstName.isNotEmpty == true ? profile!.firstName : 'Cliente';
    final repo = context.read<AppointmentRepository>();

    return Scaffold(
      appBar: AppBar(title: Text('Hola, $greetingName 👋')),
      body: StreamBuilder<List<Appointment>>(
        stream: profile == null ? const Stream<List<Appointment>>.empty() : repo.watchByClient(profile.uid),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final now = DateTime.now();
          final upcoming = all
              .where((a) => a.date.isAfter(now) && (a.status == AppointmentStatus.pending || a.status == AppointmentStatus.accepted))
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          final today = upcoming.where((a) => a.date.year == now.year && a.date.month == now.month && a.date.day == now.day).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Tu estilo, nuestra prioridad', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hoy', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$today', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                          const Text('Citas programadas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Vamos por más!', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Agenda tu próxima cita y luce increíble.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Mis próximas citas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
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
                    subtitle: 'Agenda tu primera cita y luce increíble.',
                  ),
                )
              else
                for (final appointment in upcoming.take(3)) ...[
                  AppointmentCard(appointment: appointment, subtitle: 'Con ${appointment.barberName}'),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}
