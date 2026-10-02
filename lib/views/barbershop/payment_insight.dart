import 'package:flutter/material.dart';

import '../../models/barbershop.dart';
import '../../theme/app_colors.dart';

/// Días de gracia entre el vencimiento y el bloqueo automático (spec 12.5),
/// espejo exacto de GRACE_PERIOD_MS en
/// functions/src/barbershops/subscriptionService.ts (3 a 5 días, punto
/// medio = 4). Se usa también como ventana simétrica de aviso "vence
/// pronto" antes del vencimiento, para que el admin no se entere del
/// vencimiento el mismo día que ocurre.
const kPaymentWindowDays = 4;

enum PaymentInsightLevel { ok, dueSoon, grace, graceExpired, blocked }

class PaymentInsight {
  final String label;
  final String? detail;
  final Color color;
  final PaymentInsightLevel level;

  const PaymentInsight({
    required this.label,
    this.detail,
    required this.color,
    required this.level,
  });
}

PaymentInsight paymentInsight(Barbershop shop, {DateTime? now}) {
  final today = now ?? DateTime.now();

  if (shop.paymentStatus == PaymentStatus.blocked) {
    return const PaymentInsight(
      label: 'Bloqueada',
      detail: 'Sin acceso hasta regularizar el pago',
      color: AppColors.error,
      level: PaymentInsightLevel.blocked,
    );
  }

  final due = shop.paymentDueDate;

  if (shop.paymentStatus == PaymentStatus.overdue) {
    if (due == null) {
      return const PaymentInsight(
        label: 'En mora',
        color: AppColors.warning,
        level: PaymentInsightLevel.grace,
      );
    }
    final daysOverdue = today.difference(due).inDays;
    final daysLeft = kPaymentWindowDays - daysOverdue;
    if (daysLeft > 0) {
      return PaymentInsight(
        label: 'Período de gracia',
        detail: daysLeft == 1
            ? 'Queda 1 día antes del bloqueo automático'
            : 'Quedan $daysLeft días antes del bloqueo automático',
        color: AppColors.warning,
        level: PaymentInsightLevel.grace,
      );
    }
    return const PaymentInsight(
      label: 'Gracia vencida',
      detail: 'Ya debería bloquearse por impago',
      color: AppColors.error,
      level: PaymentInsightLevel.graceExpired,
    );
  }

  // paymentStatus == ok
  if (due == null) {
    return const PaymentInsight(
      label: 'Al día',
      color: AppColors.success,
      level: PaymentInsightLevel.ok,
    );
  }
  final daysUntilDue = due.difference(today).inDays;
  if (daysUntilDue <= kPaymentWindowDays) {
    final detail = daysUntilDue <= 0
        ? 'Vence hoy'
        : daysUntilDue == 1
        ? 'Vence mañana'
        : 'Vence en $daysUntilDue días';
    return PaymentInsight(
      label: 'Vence pronto',
      detail: detail,
      color: AppColors.warning,
      level: PaymentInsightLevel.dueSoon,
    );
  }
  return PaymentInsight(
    label: 'Al día',
    detail: 'Vence el ${due.day}/${due.month}/${due.year}',
    color: AppColors.success,
    level: PaymentInsightLevel.ok,
  );
}

/// Aviso que ve el dueño en su gestión (nivel + texto + acción sugerida).
class ShopAlert {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const ShopAlert({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}

/// Alertas de UNA barbería del dueño: primero el estado de revisión y luego
/// el de la mensualidad (vence pronto, gracia, bloqueo). Lista vacía = todo
/// en orden. Un borrador no tiene alertas de mensualidad: aún no se paga.
List<ShopAlert> shopAlerts(Barbershop shop, {DateTime? now}) {
  switch (shop.approvalStatus) {
    case BarbershopApprovalStatus.draft:
      return const [
        ShopAlert(
          title: 'Borrador sin pagar',
          message: 'Págala para enviarla a revisión; mientras tanto nadie más la ve.',
          color: AppColors.warning,
          icon: Icons.edit_note_outlined,
        ),
      ];
    case BarbershopApprovalStatus.pending:
      return const [
        ShopAlert(
          title: 'Pendiente de revisión',
          message: 'El administrador debe aprobarla antes de que aparezca en el catálogo. Tu mensualidad arranca al aprobarse.',
          color: AppColors.warning,
          icon: Icons.hourglass_top_outlined,
        ),
      ];
    case BarbershopApprovalStatus.rejected:
      return const [
        ShopAlert(
          title: 'Barbería rechazada',
          message: 'El administrador la rechazó. Ajusta los datos o contáctalo; no aparece en el catálogo.',
          color: AppColors.error,
          icon: Icons.cancel_outlined,
        ),
      ];
    case BarbershopApprovalStatus.approved:
      final insight = paymentInsight(shop, now: now);
      return switch (insight.level) {
        PaymentInsightLevel.ok => const [],
        PaymentInsightLevel.dueSoon => [
          ShopAlert(
            title: 'Tu mensualidad está por vencer',
            message: '${insight.detail}. Págala para no perder el acceso.',
            color: insight.color,
            icon: Icons.schedule_outlined,
          ),
        ],
        PaymentInsightLevel.grace => [
          ShopAlert(
            title: 'Mensualidad vencida',
            message:
                '${insight.detail ?? 'Estás en mora'}. Págala ya para evitar el bloqueo.',
            color: insight.color,
            icon: Icons.warning_amber_rounded,
          ),
        ],
        PaymentInsightLevel.graceExpired => [
          ShopAlert(
            title: 'Mensualidad vencida sin pagar',
            message: 'Terminó el período de gracia: tu barbería puede bloquearse en cualquier momento. Paga ahora.',
            color: insight.color,
            icon: Icons.error_outline,
          ),
        ],
        PaymentInsightLevel.blocked => [
          ShopAlert(
            title: 'Barbería bloqueada',
            message: 'No aparece en el catálogo ni recibe citas. Paga la mensualidad para reactivarla.',
            color: insight.color,
            icon: Icons.lock_outline,
          ),
        ],
      };
  }
}

/// Tarjeta de alerta; con [onAction] muestra el botón de acción a la derecha.
class ShopAlertBanner extends StatelessWidget {
  final ShopAlert alert;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ShopAlertBanner({
    super.key,
    required this.alert,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alert.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.icon, size: 20, color: alert.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: alert.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: alert.color,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
