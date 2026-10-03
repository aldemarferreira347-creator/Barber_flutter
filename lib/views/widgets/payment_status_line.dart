import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../repositories/payment_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// Construye con el pago [paymentId] en vivo (null mientras carga o si no
/// existe / no se puede leer).
class PaymentStreamBuilder extends StatelessWidget {
  final String? paymentId;
  final Widget Function(BuildContext context, PaymentRecord? payment) builder;

  const PaymentStreamBuilder({
    super.key,
    required this.paymentId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final id = paymentId;
    if (id == null) return builder(context, null);
    return StreamBuilder<PaymentRecord?>(
      stream: context.read<PaymentRepository>().watchPayment(id),
      builder: (context, snapshot) => builder(context, snapshot.data),
    );
  }
}

/// Estado de un pago Nequi en una línea: en verificación, confirmado,
/// rechazado o reembolsado.
class PaymentStatusLine extends StatelessWidget {
  final PaymentRecord payment;

  /// Muestra la referencia del comprobante (útil para quien verifica).
  final bool showReference;

  const PaymentStatusLine({
    super.key,
    required this.payment,
    this.showReference = true,
  });

  ({IconData icon, Color color, String label}) get _look =>
      switch (payment.status) {
        PaymentIntentStatus.pending => (
          icon: Icons.hourglass_top_outlined,
          color: AppColors.warning,
          label: 'Pago en verificación',
        ),
        PaymentIntentStatus.approved => (
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          label: 'Pago confirmado',
        ),
        PaymentIntentStatus.rejected => (
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          label: 'Pago rechazado',
        ),
        PaymentIntentStatus.refunded => (
          icon: Icons.undo,
          color: AppColors.accent,
          label: payment.refundMethod == null
              ? 'Reembolsado'
              : 'Reembolsado por ${payment.refundMethod!.label}',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final reference = showReference && (payment.reference?.isNotEmpty ?? false)
        ? ' · Ref. ${payment.reference}'
        : '';
    final color = AppColors.readable(look.color);
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(look.icon, size: 16, color: color),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(
              '${look.label} · ${formatCop(payment.amount)}$reference',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
