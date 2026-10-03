import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/appointment.dart';
import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../models/refund_request.dart';
import '../../repositories/appointment_repository.dart';
import '../../repositories/refund_request_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/choice_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_badge.dart';

/// Panel del dueño para aprobar/rechazar solicitudes de cancelación con
/// justificación de citas pagadas (spec 6.3, 6.5). Al aprobar, el dueño
/// devuelve el dinero por Nequi o en efectivo y la app deja constancia.
class RefundRequestsView extends StatelessWidget {
  final String barbershopId;

  const RefundRequestsView({super.key, required this.barbershopId});

  Color _statusColor(RefundRequestStatus status) => switch (status) {
    RefundRequestStatus.pending => AppColors.warning,
    RefundRequestStatus.approved => AppColors.success,
    RefundRequestStatus.rejected => AppColors.error,
  };

  Future<void> _reject(BuildContext context, RefundRequest request) async {
    final repo = context.read<RefundRequestRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppDialog.confirm(
      context,
      title: 'Rechazar solicitud',
      message:
          'La cita sigue en pie y el cliente no recibirá reembolso. ¿Rechazar '
          'la solicitud?',
      confirmLabel: 'Rechazar',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.resolve(request.id, approve: false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo resolver: $e')),
      );
    }
  }

  Future<void> _approve(
    BuildContext context,
    RefundRequest request,
    Appointment appointment,
    PaymentRecord? payment,
  ) async {
    final repo = context.read<RefundRequestRepository>();
    final messenger = ScaffoldMessenger.of(context);
    // Un pago sin verificar no se devolvió porque nunca se recibió: se
    // cancela sin pedir medio de reembolso.
    final needsMethod =
        payment != null && payment.status == PaymentIntentStatus.approved;
    RefundMethod? method;
    if (needsMethod) {
      method = await AppBottomSheet.show<RefundMethod>(
        context,
        title: 'Aprobar reembolso',
        child: _RefundMethodForm(amount: appointment.servicePrice),
      );
      if (method == null) return;
    } else {
      final ok = await AppDialog.confirm(
        context,
        title: 'Aprobar cancelación',
        message:
            'Se cancelará la cita y el horario quedará libre. Como el pago '
            'nunca se confirmó, no hay dinero que devolver.',
        confirmLabel: 'Aprobar',
      );
      if (!ok) return;
    }
    try {
      await repo.resolve(request.id, approve: true, method: method);
      messenger.showSnackBar(
        const SnackBar(content: Text('Reembolso registrado y cita cancelada.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo resolver: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RefundRequestRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de reembolso')),
      body: StreamBuilder<List<RefundRequest>>(
        stream: repo.watchByBarbershop(barbershopId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar las solicitudes'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Sin solicitudes',
                subtitle: 'Cuando un cliente pida cancelar una cita pagada, aparecerá aquí.',
              ),
            );
          }
          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RequestCard(
                  request: request,
                  statusColor: _statusColor(request.status),
                  onReject: () => _reject(context, request),
                  onApprove: (appointment, payment) =>
                      _approve(context, request, appointment, payment),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RefundRequest request;
  final Color statusColor;
  final VoidCallback onReject;
  final void Function(Appointment appointment, PaymentRecord? payment)
  onApprove;

  const _RequestCard({
    required this.request,
    required this.statusColor,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<Appointment?>(
      stream: context.read<AppointmentRepository>().watchOne(
        request.appointmentId,
      ),
      builder: (context, snapshot) {
        final appointment = snapshot.data;
        return PaymentStreamBuilder(
          paymentId: appointment?.paymentId,
          builder: (context, payment) => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appointment == null
                            ? 'Cita'
                            : '${appointment.serviceName} · '
                                  '${appointment.clientName}',
                        style: text.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    StatusBadge(
                      label: request.status.label,
                      color: statusColor,
                    ),
                  ],
                ),
                if (appointment != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '${dateTimeLabel(appointment.date)} · '
                    '${formatCop(appointment.servicePrice)}',
                    style: text.secondary,
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                Text('Motivo del cliente', style: text.bodySmall),
                Text(request.reason),
                if (payment != null) ...[
                  const SizedBox(height: AppSpace.md),
                  PaymentStatusLine(payment: payment),
                ],
                if (request.status == RefundRequestStatus.pending) ...[
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      AppButton(
                        expand: false,
                        variant: AppButtonVariant.text,
                        onPressed: onReject,
                        child: Text(
                          'Rechazar',
                          style: TextStyle(
                            color: AppColors.readable(AppColors.error),
                          ),
                        ),
                      ),
                      AppButton(
                        expand: false,
                        onPressed: appointment == null
                            ? null
                            : () => onApprove(appointment, payment),
                        child: const Text('Aprobar'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RefundMethodForm extends StatefulWidget {
  final double amount;

  const _RefundMethodForm({required this.amount});

  @override
  State<_RefundMethodForm> createState() => _RefundMethodFormState();
}

class _RefundMethodFormState extends State<_RefundMethodForm> {
  RefundMethod? _method;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Devuelve ${formatCop(widget.amount)} al cliente y registra por qué '
          'medio lo hiciste. La cita se cancelará y el horario quedará libre.',
          style: text.secondary,
        ),
        const SizedBox(height: AppSpace.lg),
        for (final method in RefundMethod.values)
          ChoiceTile(
            selected: _method == method,
            title: method.label,
            subtitle: method == RefundMethod.nequi
                ? 'Le enviaste el dinero a su Nequi'
                : 'Le entregaste el dinero en el local',
            onTap: () => setState(() => _method = method),
          ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          onPressed: _method == null
              ? null
              : () => Navigator.of(context).pop(_method),
          child: const Text('Ya devolví el dinero'),
        ),
      ],
    );
  }
}
