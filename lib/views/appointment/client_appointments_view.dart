import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';

const _kUpcomingStatuses = {AppointmentStatus.pending, AppointmentStatus.accepted};

class ClientAppointmentsView extends StatelessWidget {
  const ClientAppointmentsView({super.key});

  Future<void> _cancel(BuildContext context, Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text('¿Cancelar tu cita de ${appointment.serviceName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppointmentRepository>().setStatus(appointment.id, AppointmentStatus.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final repo = context.read<AppointmentRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis citas')),
      body: profile == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Appointment>>(
              stream: repo.watchByClient(profile.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final appointments = snapshot.data ?? [];
                if (appointments.isEmpty) {
                  return const Center(
                    child: EmptyState(icon: Icons.event_available_outlined, title: 'No tienes citas programadas', subtitle: 'Agenda tu primera cita y luce increíble.'),
                  );
                }

                final upcoming = appointments.where((a) => _kUpcomingStatuses.contains(a.status)).toList();
                // Más reciente primero: lo último que pasó es lo más relevante del historial.
                final history = appointments.where((a) => !_kUpcomingStatuses.contains(a.status)).toList().reversed.toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionHeader(label: 'Próximas', count: upcoming.length),
                    const SizedBox(height: 10),
                    if (upcoming.isEmpty)
                      const _InlineEmptyNote(text: 'No tienes citas próximas.')
                    else
                      for (final appointment in upcoming) ...[
                        AppointmentCard(
                          appointment: appointment,
                          subtitle: 'Con ${appointment.barberName}',
                          actions: [
                            TextButton(
                              onPressed: () => _cancel(context, appointment),
                              child: const Text('Cancelar', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 18),
                    _SectionHeader(label: 'Historial', count: history.length),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      const _InlineEmptyNote(text: 'Todavía no tienes citas pasadas.')
                    else
                      for (final appointment in history) ...[
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _InlineEmptyNote extends StatelessWidget {
  final String text;

  const _InlineEmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}
