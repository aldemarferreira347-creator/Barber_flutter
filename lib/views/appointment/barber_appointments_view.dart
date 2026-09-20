import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/shimmer_box.dart';

class BarberAppointmentsView extends StatelessWidget {
  const BarberAppointmentsView({super.key});

  Future<void> _postpone(BuildContext context, Appointment appointment) async {
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.date),
    );
    if (time == null || !context.mounted) return;
    final newDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final repo = context.read<AppointmentRepository>();
    try {
      // Una cita pagada tiene el horario bloqueado con una transacción
      // (spec 6.2) — moverla debe pasar por el mismo mecanismo seguro, no
      // por una escritura directa que podría chocar con otra reserva.
      if (appointment.paid) {
        await repo.postponePaid(appointment.id, newDate);
      } else {
        await repo.reschedule(appointment.id, newDate);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo aplazar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthController>().profile;
    final repo = context.read<AppointmentRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Citas')),
      body: profile == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Appointment>>(
              stream: repo.watchByBarber(profile.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(),
                  );
                }
                final appointments = snapshot.data ?? [];
                if (appointments.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'No tienes citas programadas',
                      subtitle: 'Cuando un cliente te agende, aparecerá aquí.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    final isPending =
                        appointment.status == AppointmentStatus.pending;
                    final isUpcoming =
                        isPending ||
                        appointment.status == AppointmentStatus.accepted;
                    return AppointmentCard(
                      appointment: appointment,
                      subtitle: 'Cliente: ${appointment.clientName}',
                      animationIndex: index,
                      actions: [
                        if (isPending) ...[
                          TextButton(
                            onPressed: () => repo.setStatus(
                              appointment.id,
                              AppointmentStatus.rejected,
                            ),
                            child: const Text(
                              'Rechazar',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _postpone(context, appointment),
                            child: const Text('Aplazar'),
                          ),
                          FilledButton(
                            onPressed: () => repo.setStatus(
                              appointment.id,
                              AppointmentStatus.accepted,
                            ),
                            child: const Text('Aceptar'),
                          ),
                        ] else if (isUpcoming) ...[
                          TextButton(
                            onPressed: () => _postpone(context, appointment),
                            child: const Text('Aplazar'),
                          ),
                          FilledButton(
                            onPressed: () => repo.setStatus(
                              appointment.id,
                              AppointmentStatus.completed,
                            ),
                            child: const Text('Marcar completada'),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
