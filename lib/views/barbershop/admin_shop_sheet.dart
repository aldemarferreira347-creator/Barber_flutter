import 'package:flutter/material.dart';

import '../../models/barbershop.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/action_list_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/status_badge.dart';
import 'approval_status_badge.dart';
import 'payment_insight.dart';

/// Acciones del admin sobre una barbería.
enum AdminShopAction {
  approve,
  reject,
  info,
  manage,
  toggleActive,
  confirmPayment,
  block,
}

/// Hoja con lo que el admin puede hacer con una barbería. Solo ELIGE la
/// acción (la devuelve al cerrarse); quien la abrió pide confirmación y la
/// ejecuta.
class AdminShopSheet extends StatelessWidget {
  final Barbershop shop;
  final PaymentInsight insight;

  const AdminShopSheet({super.key, required this.shop, required this.insight});

  static Future<AdminShopAction?> show(
    BuildContext context, {
    required Barbershop shop,
    required PaymentInsight insight,
  }) {
    return AppBottomSheet.show<AdminShopAction>(
      context,
      title: shop.name,
      child: AdminShopSheet(shop: shop, insight: insight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isPending = shop.approvalStatus == BarbershopApprovalStatus.pending;
    final isApproved = shop.approvalStatus == BarbershopApprovalStatus.approved;
    final canReconsider =
        isPending || shop.approvalStatus == BarbershopApprovalStatus.rejected;

    void pick(AdminShopAction action) => Navigator.of(context).pop(action);
    const gap = SizedBox(height: AppSpace.sm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            ApprovalStatusBadge(status: shop.approvalStatus),
            if (isApproved)
              StatusBadge(label: insight.label, color: insight.color),
          ],
        ),
        if (isApproved && insight.detail != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(insight.detail!, style: text.secondary),
        ],
        if (isPending && shop.paymentId != null) ...[
          const SizedBox(height: AppSpace.md),
          PaymentStreamBuilder(
            paymentId: shop.paymentId,
            builder: (context, payment) => payment == null
                ? const SizedBox.shrink()
                : PaymentStatusLine(payment: payment),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Al aprobar la barbería confirmas que recibiste ese pago en el '
            'Nequi de la plataforma; al rechazarla, el pago queda como no '
            'recibido.',
            style: text.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        if (canReconsider) ...[
          ActionListTile(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            label: 'Aprobar barbería',
            subtitle: 'Confirma el pago y aparece en el catálogo',
            onTap: () => pick(AdminShopAction.approve),
          ),
          gap,
        ],
        if (isPending) ...[
          ActionListTile(
            icon: Icons.close,
            iconColor: AppColors.error,
            label: 'Rechazar barbería',
            subtitle: 'No aparecerá en el catálogo',
            onTap: () => pick(AdminShopAction.reject),
          ),
          gap,
        ],
        ActionListTile(
          icon: Icons.info_outline,
          label: 'Ver información',
          subtitle: 'Datos, horario y calificación',
          onTap: () => pick(AdminShopAction.info),
        ),
        gap,
        ActionListTile(
          icon: Icons.tune,
          label: 'Gestionar barbería',
          subtitle: 'Datos, barberos, servicios, productos y citas',
          onTap: () => pick(AdminShopAction.manage),
        ),
        if (isApproved) ...[
          gap,
          ActionListTile(
            icon: shop.active
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            iconColor: shop.active ? AppColors.warning : AppColors.success,
            label: shop.active ? 'Desactivar barbería' : 'Activar barbería',
            subtitle: shop.active
                ? 'Desaparece del catálogo de clientes'
                : 'Vuelve a ser visible en el catálogo',
            onTap: () => pick(AdminShopAction.toggleActive),
          ),
          if (insight.level != PaymentInsightLevel.ok) ...[
            gap,
            ActionListTile(
              icon: Icons.payments_outlined,
              iconColor: AppColors.success,
              label: 'Registrar pago recibido',
              subtitle: 'Mensualidad al día y nuevo ciclo de 30 días',
              onTap: () => pick(AdminShopAction.confirmPayment),
            ),
          ],
          if (shop.paymentStatus != PaymentStatus.blocked) ...[
            gap,
            ActionListTile(
              icon: Icons.lock_outline,
              iconColor: AppColors.error,
              label: 'Bloquear por impago',
              subtitle: 'Bloquea la barbería y la oculta del catálogo',
              onTap: () => pick(AdminShopAction.block),
            ),
          ],
        ],
      ],
    );
  }
}
