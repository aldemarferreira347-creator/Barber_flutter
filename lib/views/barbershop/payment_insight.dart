import 'package:flutter/material.dart';

import '../../models/barbershop.dart';
import '../../models/platform_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';

/// Días que se avisa "vence pronto" antes del vencimiento, para que el dueño
/// y el admin no se enteren el mismo día que ocurre.
const kDueSoonDays = 4;

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

/// Estado de la mensualidad de [shop], DERIVADO de su fecha de vencimiento y
/// de los [graceDays] de gracia: no depende de que un proceso en el servidor
/// haya actualizado `paymentStatus` (sin plan Blaze no corre ninguno). Las
/// reglas aplican el mismo criterio al aceptar citas.
PaymentInsight paymentInsight(
  Barbershop shop, {
  DateTime? now,
  int graceDays = PlatformSettings.kDefaultGraceDays,
}) {
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

  final overdueByDate = due != null && today.isAfter(due);
  if (shop.paymentStatus == PaymentStatus.overdue || overdueByDate) {
    if (due == null) {
      return const PaymentInsight(
        label: 'En mora',
        color: AppColors.warning,
        level: PaymentInsightLevel.grace,
      );
    }
    final daysOverdue = today.difference(due).inDays;
    final daysLeft = graceDays - daysOverdue;
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
      label: 'Bloqueada por mora',
      detail: 'Terminó la gracia: paga para reactivarla',
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
  if (daysUntilDue <= kDueSoonDays) {
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
List<ShopAlert> shopAlerts(
  Barbershop shop, {
  DateTime? now,
  int graceDays = PlatformSettings.kDefaultGraceDays,
}) {
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
          message: 'El administrador verificará tu pago y revisará la barbería antes de mostrarla en el catálogo. Tu mensualidad arranca al aprobarse.',
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
      final insight = paymentInsight(shop, now: now, graceDays: graceDays);
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
            title: 'Barbería bloqueada por mora',
            message: 'Terminó el período de gracia: no aparece en el catálogo ni recibe citas. Paga la mensualidad para reactivarla.',
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
    final text = Theme.of(context).textTheme;
    final color = AppColors.readable(alert.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: AppColors.tint(alert.color),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: alert.color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(alert.icon, size: 20, color: color),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: text.titleSmall?.copyWith(color: color),
                        ),
                        const SizedBox(height: 2),
                        Text(alert.message, style: text.secondary),
                      ],
                    ),
                  ),
                ],
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: AppSpace.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    expand: false,
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
