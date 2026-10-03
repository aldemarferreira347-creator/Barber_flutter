import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/barbershop.dart';
import '../../models/purchase.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/shimmer_box.dart';
import '../widgets/status_badge.dart';
import 'claim_code_card.dart';

/// Historial de compras de productos del cliente. Es el lugar donde vuelve a
/// ver su código de reclamo (y cuánto tiempo le queda) después de comprar.
class MyPurchasesView extends StatelessWidget {
  const MyPurchasesView({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthController>().profile?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis compras')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<Purchase>>(
              stream: context.read<PurchaseRepository>().watchByBuyer(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: ErrorState(title: 'No pudimos cargar tus compras'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpace.lg),
                    child: ShimmerList(),
                  );
                }
                final purchases = snapshot.data!;
                if (purchases.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Aún no has comprado productos',
                      subtitle:
                          'Entra a una barbería y elige un producto para '
                          'comprarlo con Nequi.',
                    ),
                  );
                }
                return ResponsiveBody(
                  maxWidth: AppLayout.formWidth,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                    itemCount: purchases.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpace.md),
                    itemBuilder: (context, index) =>
                        _PurchaseCard(purchase: purchases[index]),
                  ),
                );
              },
            ),
    );
  }
}

Color _statusColor(PurchaseStatus status) => switch (status) {
  PurchaseStatus.pendingPayment => AppColors.warning,
  PurchaseStatus.pendingClaim => AppColors.accent,
  PurchaseStatus.claimed => AppColors.success,
  PurchaseStatus.expired => AppColors.error,
  PurchaseStatus.paymentFailed => AppColors.error,
};

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = purchase.displayStatus;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<Barbershop?>(
                  stream: context.read<BarbershopRepository>().watchOne(
                    purchase.barbershopId,
                  ),
                  builder: (context, snapshot) => Text(
                    snapshot.data?.name ?? 'Barbería',
                    style: text.titleSmall,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              StatusBadge(label: status.label, color: _statusColor(status)),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(purchase.itemsLabel, style: text.secondary),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  purchase.createdAt == null
                      ? ''
                      : dateTimeLabel(purchase.createdAt!),
                  style: text.bodySmall,
                ),
              ),
              Text(formatCop(purchase.totalAmount), style: text.titleSmall),
            ],
          ),
          if (status == PurchaseStatus.pendingPayment ||
              status == PurchaseStatus.paymentFailed) ...[
            const SizedBox(height: AppSpace.sm),
            PaymentStreamBuilder(
              paymentId: purchase.paymentId,
              builder: (context, payment) => payment == null
                  ? const SizedBox.shrink()
                  : PaymentStatusLine(payment: payment),
            ),
          ],
          if (status == PurchaseStatus.pendingClaim &&
              purchase.claimCode != null) ...[
            const SizedBox(height: AppSpace.md),
            ClaimCodeCard(
              code: purchase.claimCode!,
              expiresAt: purchase.expiresAt,
            ),
          ],
          if (status == PurchaseStatus.expired) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'Pasaron más de 24 horas sin reclamarla. Comunícate con la '
              'barbería.',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
