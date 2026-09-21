import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/appointment_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import 'rate_appointment_view.dart';

// 'postponed' cuenta como próxima: su `date` ya es la nueva fecha futura
// tras el cambio (spec 6.4) — sigue siendo una cita activa, no pasada.
const _kUpcomingStatuses = {
  AppointmentStatus.pending,
  AppointmentStatus.accepted,
  AppointmentStatus.postponed,
};

class ClientAppointmentsView extends StatelessWidget {
  const ClientAppointmentsView({super.key});

  Future<void> _cancel(BuildContext context, Appointment appointment) async {
    if (appointment.paid) {
      await _cancelPaid(context, appointment);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text('¿Cancelar tu cita de ${appointment.serviceName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppointmentRepository>().setStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
    }
  }

  /// Una cita pagada nunca se cancela directamente: primero se ofrece
  /// posponer (conservando el pago); solo si el cliente insiste, se le
  /// pide una justificación que el dueño debe aprobar (spec 6.3).
  Future<void> _cancelPaid(
    BuildContext context,
    Appointment appointment,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esta cita ya está pagada'),
        content: const Text(
          'En vez de cancelarla y perder tu horario, puedes posponerla a otra fecha conservando el pago ya realizado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancelar de todas formas'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('postpone'),
            child: const Text('Posponer'),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'postpone') {
      await _postponePaid(context, appointment);
    } else if (choice == 'cancel') {
      await _requestCancellation(context, appointment);
    }
  }

  Future<void> _postponePaid(
    BuildContext context,
    Appointment appointment,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
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

    try {
      await context.read<AppointmentRepository>().postponePaid(
        appointment.id,
        newDate,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita pospuesta. Tu pago sigue en pie.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo posponer: $e')));
      }
    }
  }

  Future<void> _requestCancellation(
    BuildContext context,
    Appointment appointment,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Justifica la cancelación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'El dueño de la barbería revisará esta justificación antes de aprobar el reembolso.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Cuéntanos qué pasó...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;

    try {
      await context.read<AppointmentRepository>().requestRefund(
        appointmentId: appointment.id,
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Te avisaremos cuando el dueño la revise.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la solicitud: $e')),
        );
      }
    }
  }

  bool _canRate(Appointment appointment) =>
      appointment.paid && appointment.status == AppointmentStatus.completed;

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
                if (snapshot.hasError) {
                  return const Center(
                    child: ErrorState(title: 'No pudimos cargar tus citas'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: ShimmerList(count: 4),
                  );
                }
                final appointments = snapshot.data ?? [];
                if (appointments.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'No tienes citas programadas',
                      subtitle: 'Agenda tu primera cita y luce increíble.',
                    ),
                  );
                }

                final upcoming = appointments
                    .where((a) => _kUpcomingStatuses.contains(a.status))
                    .toList();
                // Más reciente primero: lo último que pasó es lo más relevante del historial.
                final history = appointments
                    .where((a) => !_kUpcomingStatuses.contains(a.status))
                    .toList()
                    .reversed
                    .toList();

                return StreamBuilder<Set<String>>(
                  stream: context
                      .read<RatingRepository>()
                      .watchRatedAppointmentIds(profile.uid),
                  builder: (context, ratedSnapshot) {
                    // Este stream solo decide si se muestra el botón
                    // "Calificar" por cita; si falla, no bloqueamos el
                    // historial completo, simplemente no mostramos el botón.
                    final ratedIds = ratedSnapshot.hasError
                        ? const <String>{}
                        : (ratedSnapshot.data ?? const <String>{});

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SectionHeader(
                          label: 'Próximas',
                          count: upcoming.length,
                        ),
                        const SizedBox(height: 10),
                        if (upcoming.isEmpty)
                          const _InlineEmptyNote(
                            text: 'No tienes citas próximas.',
                          )
                        else
                          for (final entry in upcoming.indexed) ...[
                            AppointmentCard(
                              appointment: entry.$2,
                              subtitle: 'Con ${entry.$2.barberName}',
                              animationIndex: entry.$1,
                              actions: [
                                TextButton(
                                  onPressed: () => _cancel(context, entry.$2),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        const SizedBox(height: 18),
                        _SectionHeader(
                          label: 'Historial',
                          count: history.length,
                        ),
                        const SizedBox(height: 10),
                        if (history.isEmpty)
                          const _InlineEmptyNote(
                            text: 'Todavía no tienes citas pasadas.',
                          )
                        else
                          for (final entry in history.indexed) ...[
                            AppointmentCard(
                              appointment: entry.$2,
                              subtitle: 'Con ${entry.$2.barberName}',
                              animationIndex: entry.$1,
                              actions:
                                  _canRate(entry.$2) &&
                                      !ratedIds.contains(entry.$2.id)
                                  ? [
                                      TextButton(
                                        onPressed: () => Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RateAppointmentView(
                                                      appointment: entry.$2,
                                                    ),
                                              ),
                                            ),
                                        child: const Text('Calificar'),
                                      ),
                                    ]
                                  : const [],
                            ),
                            const SizedBox(height: 10),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.05, end: 0, curve: Curves.easeOutCubic);
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
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
