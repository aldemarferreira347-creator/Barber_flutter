import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../repositories/appointment_repository.dart';
import '../../theme/app_colors.dart';
import 'app_button.dart';
import 'app_dialog.dart';
import 'appointment_card.dart';
import 'payment_status_line.dart';

/// Tarjeta de una cita para quien atiende (barbero o dueño): reúne las
/// acciones de la cita y, si es una cita pagada con Nequi, la verificación
/// del pago.
///
/// Una cita pagada no se acepta "a ciegas": primero se confirma que el
/// dinero llegó al Nequi (que acepta la cita en la misma escritura) o se
/// rechaza el pago (que cancela la cita y libera el horario).
class StaffAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String subtitle;

  const StaffAppointmentCard({
    super.key,
    required this.appointment,
    required this.subtitle,
  });

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String failure,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$failure: $e')));
      }
    }
  }

  Future<void> _postpone(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.date.isAfter(DateTime.now())
          ? appointment.date
          : DateTime.now(),
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
    await _run(context, () {
      // Una cita pagada tiene el horario bloqueado con una transacción
      // (spec 6.2) — moverla debe pasar por el mismo mecanismo seguro, no
      // por una escritura directa que podría chocar con otra reserva.
      return appointment.paid
          ? repo.postponePaid(appointment.id, newDate)
          : repo.reschedule(appointment.id, newDate);
    }, 'No se pudo aplazar');
  }

  Future<void> _confirmPayment(
    BuildContext context,
    PaymentRecord payment,
  ) async {
    final repo = context.read<AppointmentRepository>();
    final ok = await AppDialog.confirm(
      context,
      title: 'Confirmar pago',
      message:
          'Confirma solo si ya ves ${formatCop(payment.amount)} en tu Nequi '
          'con la referencia ${payment.reference ?? '—'}. La cita de '
          '${appointment.clientName} quedará aceptada.',
      confirmLabel: 'Sí, lo recibí',
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => repo.confirmPayment(appointment.id),
      'No se pudo confirmar',
    );
  }

  Future<void> _rejectPayment(BuildContext context) async {
    final repo = context.read<AppointmentRepository>();
    final ok = await AppDialog.confirm(
      context,
      title: 'Rechazar pago',
      message:
          'Se cancelará la cita de ${appointment.clientName} y el horario '
          'quedará libre. Hazlo solo si el dinero no llegó a tu Nequi.',
      confirmLabel: 'Rechazar pago',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => repo.rejectPayment(appointment.id),
      'No se pudo rechazar',
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    AppointmentStatus status, {
    String? confirmTitle,
    String? confirmMessage,
  }) async {
    final repo = context.read<AppointmentRepository>();
    if (confirmTitle != null) {
      final ok = await AppDialog.confirm(
        context,
        title: confirmTitle,
        message: confirmMessage ?? '',
        confirmLabel: 'Rechazar',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    await _run(
      context,
      () => repo.setStatus(appointment.id, status),
      'No se pudo actualizar',
    );
  }

  List<Widget> _actions(BuildContext context, PaymentRecord? payment) {
    final status = appointment.status;
    final awaitingPayment =
        appointment.paid &&
        (payment?.isPending ?? false) &&
        (status == AppointmentStatus.pending ||
            status == AppointmentStatus.postponed);

    if (awaitingPayment) {
      return [
        AppButton(
          key: const ValueKey('reject-payment'),
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => _rejectPayment(context),
          child: Text(
            'No lo recibí',
            style: TextStyle(color: AppColors.readable(AppColors.error)),
          ),
        ),
        AppButton(
          key: const ValueKey('confirm-payment'),
          expand: false,
          icon: Icons.check,
          onPressed: () => _confirmPayment(context, payment!),
          child: const Text('Confirmar pago'),
        ),
      ];
    }
    if (status == AppointmentStatus.pending) {
      return [
        AppButton(
          key: const ValueKey('reject-appointment'),
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => _setStatus(
            context,
            AppointmentStatus.rejected,
            confirmTitle: 'Rechazar cita',
            confirmMessage:
                '${appointment.clientName} recibirá la cita como rechazada.',
          ),
          child: Text(
            'Rechazar',
            style: TextStyle(color: AppColors.readable(AppColors.error)),
          ),
        ),
        AppButton(
          key: const ValueKey('postpone-appointment'),
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => _postpone(context),
          child: const Text('Aplazar'),
        ),
        AppButton(
          key: const ValueKey('accept-appointment'),
          expand: false,
          onPressed: () => _setStatus(context, AppointmentStatus.accepted),
          child: const Text('Aceptar'),
        ),
      ];
    }
    if (status == AppointmentStatus.accepted) {
      return [
        AppButton(
          key: const ValueKey('postpone-appointment'),
          expand: false,
          variant: AppButtonVariant.text,
          onPressed: () => _postpone(context),
          child: const Text('Aplazar'),
        ),
        AppButton(
          key: const ValueKey('complete-appointment'),
          expand: false,
          onPressed: () => _setStatus(context, AppointmentStatus.completed),
          child: const Text('Marcar completada'),
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return PaymentStreamBuilder(
      paymentId: appointment.paid ? appointment.paymentId : null,
      builder: (context, payment) => AppointmentCard(
        appointment: appointment,
        subtitle: subtitle,
        payment: payment,
        actions: _actions(context, payment),
      ),
    );
  }
}
