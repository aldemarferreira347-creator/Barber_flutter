import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/staff_appointment_card.dart';

class BarberAppointmentsView extends StatelessWidget {
  const BarberAppointmentsView({super.key});

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
                if (snapshot.hasError) {
                  return const Center(
                    child: ErrorState(title: 'No pudimos cargar tus citas'),
                  );
                }
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
                    return StaffAppointmentCard(
                      appointment: appointment,
                      subtitle: 'Cliente: ${appointment.clientName}',
                    );
                  },
                );
              },
            ),
    );
  }
}
