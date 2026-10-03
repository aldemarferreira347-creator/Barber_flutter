import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/barbershop_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/day_time_picker.dart';
import '../widgets/shimmer_box.dart';
import '../../utils/error_text.dart';

/// Qué decide el cliente ante una cita ya pagada.
enum PaidCancelChoice { postpone, cancel }

/// Primera pantalla al cancelar una cita pagada: se ofrece posponer
/// conservando el pago antes de pedir la cancelación (spec 6.3).
class PaidCancelChoiceForm extends StatelessWidget {
  const PaidCancelChoiceForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'En vez de cancelarla y perder tu horario, puedes posponerla a '
          'otra fecha conservando el pago ya realizado.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          onPressed: () => Navigator.of(context).pop(PaidCancelChoice.postpone),
          icon: Icons.event_repeat,
          child: const Text('Posponer'),
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(PaidCancelChoice.cancel),
          child: const Text('Cancelar de todas formas'),
        ),
      ],
    );
  }
}

/// Elige un nuevo día y hora DENTRO del horario de la barbería y mueve la
/// cita conservando el pago. Cierra la hoja con `true` al terminar.
class PostponeForm extends StatefulWidget {
  final Appointment appointment;

  const PostponeForm({super.key, required this.appointment});

  @override
  State<PostponeForm> createState() => _PostponeFormState();
}

class _PostponeFormState extends State<PostponeForm> {
  late final Stream<Barbershop?> _shop = context
      .read<BarbershopRepository>()
      .watchOne(widget.appointment.barbershopId);
  DateTime? _day;
  DateTime? _dateTime;
  String? _error;

  Future<void> _confirm() async {
    final newDate = _dateTime;
    if (newDate == null) {
      setState(() => _error = 'Elige el nuevo día y hora.');
      return;
    }
    try {
      await context.read<AppointmentRepository>().postponePaid(
        widget.appointment.id,
        newDate,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final appointment = widget.appointment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${appointment.serviceName} con ${appointment.barberName}. '
          'Ahora: ${dateTimeLabel(appointment.date)}. Tu pago sigue en pie.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.lg),
        StreamBuilder<Barbershop?>(
          stream: _shop,
          builder: (context, snapshot) {
            final shop = snapshot.data;
            if (shop == null) {
              return snapshot.hasError
                  ? Text(
                      'No pudimos cargar el horario de la barbería.',
                      style: text.bodyMedium,
                    )
                  : const ShimmerList(count: 1, itemHeight: 58);
            }
            return DayAndTimePicker(
              shop: shop,
              durationMinutes: appointment.durationMinutes,
              day: _day,
              dateTime: _dateTime,
              onDay: (day) => setState(() {
                _day = day;
                _dateTime = null;
                _error = null;
              }),
              onTime: (time) => setState(() {
                _dateTime = time;
                _error = null;
              }),
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: AppColors.readable(AppColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        AppButton(
          onPressed: _confirm,
          icon: Icons.event_repeat,
          child: const Text('Confirmar nuevo horario'),
        ),
      ],
    );
  }
}

/// Justificación de la cancelación de una cita pagada: el dueño la revisa
/// antes de aprobar el reembolso. Envía la solicitud y cierra con `true`.
class RefundReasonForm extends StatefulWidget {
  final String appointmentId;

  const RefundReasonForm({super.key, required this.appointmentId});

  @override
  State<RefundReasonForm> createState() => _RefundReasonFormState();
}

class _RefundReasonFormState extends State<RefundReasonForm> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Cuéntanos el motivo para poder revisarlo.');
      return;
    }
    try {
      await context.read<AppointmentRepository>().requestRefund(
        appointmentId: widget.appointmentId,
        reason: reason,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo enviar la solicitud: ${errorText(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'El dueño de la barbería revisará esta justificación antes de '
          'aprobar el reembolso.',
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _reason,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Cuéntanos qué pasó...',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: AppColors.readable(AppColors.error),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        AppButton(
          onPressed: _send,
          icon: Icons.send_outlined,
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}
