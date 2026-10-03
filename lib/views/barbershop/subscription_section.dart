import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../models/platform_settings.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/platform_settings_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/nequi_payment_sheet.dart';
import '../widgets/payment_status_line.dart';
import 'payment_insight.dart';
import '../../utils/error_text.dart';

/// Mensualidad de una barbería aprobada, vista por su dueño: alertas de
/// vencimiento o mora, estado del último pago Nequi y botón para pagar. El
/// pago lo confirma el administrador al verificar su Nequi; mientras tanto se
/// muestra "en verificación" y no se puede enviar otro.
class SubscriptionSection extends StatelessWidget {
  final Barbershop shop;

  const SubscriptionSection({super.key, required this.shop});

  Future<void> _pay(BuildContext context, PlatformSettings settings) async {
    final repo = context.read<BarbershopRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final reference = await showNequiPaymentSheet(
      context,
      title: 'Pagar mensualidad',
      amount: settings.monthlyFee,
      payeeName: 'BarberFlow',
      payeePhone: settings.nequiPhone!,
      verifier: 'el administrador de BarberFlow',
    );
    if (reference == null) return;
    try {
      await repo.paySubscription(shop.id, reference: reference);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante enviado. El administrador verificará tu pago.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar el pago: ${errorText(e)}'),
        ),
      );
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final repo = context.read<BarbershopRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Cancelar membresía',
      message:
          'Tu barbería se bloqueará de inmediato, sin período de gracia. Las '
          'citas ya pagadas dentro del período vigente no se ven afectadas.',
      confirmLabel: 'Sí, cancelar',
      cancelLabel: 'Volver',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await repo.cancelSubscription(shop.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: ${errorText(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<PlatformSettings>(
      stream: context.read<PlatformSettingsRepository>().watch(),
      initialData: PlatformSettings.defaults,
      builder: (context, settingsSnapshot) {
        final settings = settingsSnapshot.data ?? PlatformSettings.defaults;
        return StreamBuilder<List<PaymentRecord>>(
          stream: context.read<PaymentRepository>().watchSubscriptionPayments(
            payerId: shop.ownerId,
            shopId: shop.id,
          ),
          builder: (context, paymentsSnapshot) {
            final latest =
                (paymentsSnapshot.data ?? const <PaymentRecord>[]).firstOrNull;
            final awaiting = latest != null && latest.isPending;
            final insight = paymentInsight(shop, graceDays: settings.graceDays);
            final needsPayment = insight.level != PaymentInsightLevel.ok;
            final canPay = settings.canCharge && !awaiting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final alert in shopAlerts(
                  shop,
                  graceDays: settings.graceDays,
                ))
                  ShopAlertBanner(
                    alert: alert,
                    actionLabel: canPay
                        ? 'Pagar ${formatCop(settings.monthlyFee)}'
                        : null,
                    onAction: canPay ? () => _pay(context, settings) : null,
                  ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppColors.readable(insight.color),
                          ),
                          const SizedBox(width: AppSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mensualidad: ${insight.label.toLowerCase()}',
                                  style: text.titleSmall,
                                ),
                                if (insight.detail != null)
                                  Text(insight.detail!, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (latest != null) ...[
                        const SizedBox(height: AppSpace.md),
                        PaymentStatusLine(payment: latest),
                        if (latest.createdAt != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 20,
                              top: AppSpace.xs,
                            ),
                            child: Text(
                              'Enviado ${dateTimeLabel(latest.createdAt!)}',
                              style: text.bodySmall,
                            ),
                          ),
                      ],
                      if (!settings.canCharge) ...[
                        const SizedBox(height: AppSpace.md),
                        Text(
                          'El administrador aún no configuró el Nequi de la '
                          'plataforma, por eso todavía no puedes pagar desde '
                          'la app.',
                          style: text.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          if (insight.level == PaymentInsightLevel.ok &&
                              !awaiting)
                            AppButton(
                              expand: false,
                              variant: AppButtonVariant.text,
                              onPressed: () => _cancel(context),
                              child: Text(
                                'Cancelar membresía',
                                style: TextStyle(
                                  color: AppColors.readable(AppColors.error),
                                ),
                              ),
                            ),
                          if (canPay)
                            AppButton(
                              expand: false,
                              variant: needsPayment
                                  ? AppButtonVariant.primary
                                  : AppButtonVariant.secondary,
                              icon: Icons.payments_outlined,
                              onPressed: () => _pay(context, settings),
                              child: Text(
                                'Pagar ${formatCop(settings.monthlyFee)}',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
