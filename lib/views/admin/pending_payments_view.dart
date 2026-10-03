import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../barbershop/manage_barbershops_view.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';

/// Mensualidades que los dueños dicen haber transferido al Nequi de la
/// plataforma. El admin verifica cada una en su propio Nequi: si el dinero
/// llegó la confirma (la barbería queda al día 30 días más) y si no, la
/// rechaza. La primera mensualidad de una barbería nueva se confirma al
/// aprobarla, desde la gestión de barberías.
class PendingPaymentsView extends StatelessWidget {
  const PendingPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagos por verificar')),
      body: StreamBuilder<List<PaymentRecord>>(
        stream: context.read<PaymentRepository>().watchPendingSubscriptions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: ErrorState(title: 'No pudimos cargar los pagos'),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: ShimmerList(),
            );
          }
          final payments = snapshot.data!;
          if (payments.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.payments_outlined,
                title: 'Todo verificado',
                subtitle:
                    'No hay mensualidades esperando confirmación. Cuando un '
                    'dueño registre un pago aparecerá aquí.',
              ),
            );
          }
          return ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
              itemCount: payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
              itemBuilder: (context, index) =>
                  _PaymentCard(payment: payments[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;

  const _PaymentCard({required this.payment});

  Future<void> _confirm(BuildContext context, Barbershop shop) async {
    final repo = context.read<BarbershopRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppDialog.confirm(
      context,
      title: 'Confirmar mensualidad',
      message:
          'Confirma solo si ya ves ${formatCop(payment.amount)} en el Nequi '
          'de la plataforma con la referencia ${payment.reference ?? '—'}. '
          '"${shop.name}" quedará al día por 30 días más.',
      confirmLabel: 'Sí, lo recibí',
    );
    if (!ok) return;
    try {
      await repo.confirmSubscriptionPayment(payment.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Mensualidad de "${shop.name}" confirmada')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo confirmar: $e')),
      );
    }
  }

  Future<void> _reject(BuildContext context, Barbershop shop) async {
    final repo = context.read<BarbershopRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await AppDialog.confirm(
      context,
      title: 'Rechazar pago',
      message:
          'El pago de "${shop.name}" quedará como no recibido y el dueño '
          'tendrá que registrar otro. Hazlo solo si el dinero no llegó.',
      confirmLabel: 'Rechazar pago',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.rejectSubscriptionPayment(payment.id);
      messenger.showSnackBar(const SnackBar(content: Text('Pago rechazado')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo rechazar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return StreamBuilder<Barbershop?>(
      stream: context.read<BarbershopRepository>().watchOne(payment.relatedId),
      builder: (context, snapshot) {
        final shop = snapshot.data;
        final firstPayment =
            shop != null &&
            shop.approvalStatus != BarbershopApprovalStatus.approved;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop?.name ?? 'Barbería', style: text.titleSmall),
              const SizedBox(height: AppSpace.xs),
              Text(
                [
                  firstPayment ? 'Primera mensualidad' : 'Renovación',
                  if (payment.createdAt != null)
                    dateTimeLabel(payment.createdAt!),
                ].join(' · '),
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpace.sm),
              PaymentStatusLine(payment: payment),
              if (shop != null) ...[
                const SizedBox(height: AppSpace.md),
                if (firstPayment) ...[
                  Text(
                    'Este pago se confirma al aprobar la barbería.',
                    style: text.secondary,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      expand: false,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ManageBarbershopsView(
                            initialFilter: AdminShopFilter.pending,
                          ),
                        ),
                      ),
                      child: const Text('Revisar barbería'),
                    ),
                  ),
                ] else
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      AppButton(
                        expand: false,
                        variant: AppButtonVariant.text,
                        onPressed: () => _reject(context, shop),
                        child: Text(
                          'No lo recibí',
                          style: TextStyle(
                            color: AppColors.readable(AppColors.error),
                          ),
                        ),
                      ),
                      AppButton(
                        expand: false,
                        icon: Icons.check,
                        onPressed: () => _confirm(context, shop),
                        child: const Text('Confirmar pago'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
