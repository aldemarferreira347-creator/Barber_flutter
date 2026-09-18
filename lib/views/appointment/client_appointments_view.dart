import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';

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
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    return AppointmentCard(
                      appointment: appointment,
                      subtitle: 'Con ${appointment.barberName}',
                      actions: appointment.status == AppointmentStatus.pending || appointment.status == AppointmentStatus.accepted
                          ? [
                              TextButton(
                                onPressed: () => _cancel(context, appointment),
                                child: const Text('Cancelar', style: TextStyle(color: AppColors.error)),
                              ),
                            ]
                          : [],
                    );
                  },
                );
              },
            ),
    );
  }
}
