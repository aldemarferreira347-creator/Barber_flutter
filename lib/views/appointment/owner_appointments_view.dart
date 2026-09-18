import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';

class OwnerAppointmentsView extends StatelessWidget {
  final String barbershopId;

  const OwnerAppointmentsView({super.key, required this.barbershopId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppointmentRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Citas de la barbería')),
      body: StreamBuilder<List<Appointment>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final appointments = snapshot.data ?? [];
          if (appointments.isEmpty) {
            return const Center(
              child: EmptyState(icon: Icons.event_available_outlined, title: 'Sin citas todavía', subtitle: 'Aquí verás todas las citas de tu barbería.'),
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
                subtitle: '${appointment.clientName} con ${appointment.barberName}',
              );
            },
          );
        },
      ),
    );
  }
}
