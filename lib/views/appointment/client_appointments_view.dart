import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/appointment.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/rating_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/appointment_card.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/shimmer_box.dart';
import 'paid_appointment_sheets.dart';
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
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cancelar cita',
      message: '¿Cancelar tu cita de ${appointment.serviceName}?',
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'No',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppointmentRepository>().setStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cancelar la cita: $e')),
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
    final choice = await AppBottomSheet.show<PaidCancelChoice>(
      context,
      title: 'Esta cita ya está pagada',
      child: const PaidCancelChoiceForm(),
    );
    if (!context.mounted || choice == null) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (choice) {
      case PaidCancelChoice.postpone:
        final done = await AppBottomSheet.show<bool>(
          context,
          title: 'Posponer cita',
          child: PostponeForm(appointment: appointment),
        );
        if (done == true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Cita pospuesta. Tu pago sigue en pie.'),
            ),
          );
        }
      case PaidCancelChoice.cancel:
        final sent = await AppBottomSheet.show<bool>(
          context,
          title: 'Justifica la cancelación',
          child: RefundReasonForm(appointmentId: appointment.id),
        );
        if (sent == true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Solicitud enviada. El dueño la revisará y verás el '
                'resultado aquí.',
              ),
            ),
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

                    return ResponsiveBody(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.lg,
                        ),
                        children: [
                          SectionHeader(title: 'Próximas (${upcoming.length})'),
                          if (upcoming.isEmpty)
                            const _InlineEmptyNote(
                              text: 'No tienes citas próximas.',
                            )
                          else
                            for (final entry in upcoming.indexed) ...[
                              PaymentStreamBuilder(
                                paymentId: entry.$2.paid
                                    ? entry.$2.paymentId
                                    : null,
                                builder: (context, payment) => AppointmentCard(
                                  appointment: entry.$2,
                                  subtitle: 'Con ${entry.$2.barberName}',
                                  payment: payment,
                                  actions: [
                                    AppButton(
                                      expand: false,
                                      variant: AppButtonVariant.text,
                                      onPressed: () =>
                                          _cancel(context, entry.$2),
                                      child: Text(
                                        'Cancelar',
                                        style: TextStyle(
                                          color: AppColors.readable(
                                            AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpace.md),
                            ],
                          const SizedBox(height: AppSpace.xl),
                          SectionHeader(title: 'Historial (${history.length})'),
                          if (history.isEmpty)
                            const _InlineEmptyNote(
                              text: 'Todavía no tienes citas pasadas.',
                            )
                          else
                            for (final entry in history.indexed) ...[
                              PaymentStreamBuilder(
                                paymentId: entry.$2.paid
                                    ? entry.$2.paymentId
                                    : null,
                                builder: (context, payment) => AppointmentCard(
                                  appointment: entry.$2,
                                  subtitle: 'Con ${entry.$2.barberName}',
                                  payment: payment,
                                  actions:
                                      _canRate(entry.$2) &&
                                          !ratedIds.contains(entry.$2.id)
                                      ? [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).push(
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
                              ),
                              const SizedBox(height: AppSpace.md),
                            ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _InlineEmptyNote extends StatelessWidget {
  final String text;

  const _InlineEmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(text, style: Theme.of(context).textTheme.secondary),
    );
  }
}
