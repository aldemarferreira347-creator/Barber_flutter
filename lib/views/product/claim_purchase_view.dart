import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/payment_record.dart';
import '../../models/purchase.dart';
import '../../repositories/purchase_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';
import '../../utils/date_labels.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

/// Compras de productos de una barbería, para quien atiende (barbero o
/// dueño): primero verifica los pagos Nequi que llegaron (al confirmarlos el
/// cliente recibe su código) y luego entrega las compras con ese código
/// (spec 10.4).
class ClaimPurchaseView extends StatefulWidget {
  final String barbershopId;

  const ClaimPurchaseView({super.key, required this.barbershopId});

  @override
  State<ClaimPurchaseView> createState() => _ClaimPurchaseViewState();
}

class _ClaimPurchaseViewState extends State<ClaimPurchaseView> {
  final _codeController = TextEditingController();
  late final Stream<List<Purchase>> _purchases = context
      .read<PurchaseRepository>()
      .watchByBarbershop(widget.barbershopId);

  Purchase? _purchase;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _purchase = null;
    });
    try {
      final purchase = await context.read<PurchaseRepository>().findByClaimCode(
        barbershopId: widget.barbershopId,
        claimCode: code,
      );
      if (!mounted) return;
      setState(() {
        _purchase = purchase;
        if (purchase == null) {
          _error =
              'No encontramos ninguna compra con ese código en esta barbería.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo buscar el código: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _claim(Purchase purchase) async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Entregar compra',
      message:
          'Confirma que entregaste ${purchase.itemsLabel}. Esta acción no '
          'se puede deshacer.',
      confirmLabel: 'Sí, entregada',
    );
    if (!ok || !mounted) return;
    try {
      await context.read<PurchaseRepository>().claimPurchase(purchase.id);
      if (!mounted) return;
      setState(() {
        _purchase = null;
        _codeController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compra marcada como entregada.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo marcar como entregada: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final purchase = _purchase;
    return Scaffold(
      appBar: AppBar(title: const Text('Compras de productos')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        children: [
          ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<List<Purchase>>(
                  stream: _purchases,
                  builder: (context, snapshot) {
                    final awaiting = [
                      for (final p in snapshot.data ?? const <Purchase>[])
                        if (p.status == PurchaseStatus.pendingPayment &&
                            p.paymentId != null)
                          p,
                    ];
                    if (awaiting.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(
                          title: 'Pagos por confirmar (${awaiting.length})',
                        ),
                        for (final p in awaiting) ...[
                          _PendingPaymentCard(purchase: p),
                          const SizedBox(height: AppSpace.md),
                        ],
                        const SizedBox(height: AppSpace.lg),
                      ],
                    );
                  },
                ),
                const SectionHeader(title: 'Entregar con código'),
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Código de reclamo',
                    prefixIcon: const Icon(Icons.qr_code),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar compra',
                      icon: const Icon(Icons.search),
                      onPressed: _searching ? null : _search,
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: AppSpace.lg),
                if (_searching)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: AppColors.readable(AppColors.error),
                    ),
                  ),
                if (purchase != null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(
                              label: purchase.displayStatus.label,
                              color: switch (purchase.displayStatus) {
                                PurchaseStatus.pendingClaim => AppColors.accent,
                                PurchaseStatus.claimed => AppColors.success,
                                _ => AppColors.error,
                              },
                            ),
                            const Spacer(),
                            Text(
                              formatCop(purchase.totalAmount),
                              style: text.titleSmall,
                            ),
                          ],
                        ),
                        const Divider(height: AppSpace.xl),
                        for (final item in purchase.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.xs,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.refunded
                                      ? Icons.remove_circle_outline
                                      : Icons.check_box_outlined,
                                  size: 18,
                                  color: AppColors.readable(
                                    item.refunded
                                        ? AppColors.error
                                        : AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    '${item.productName} ×${item.quantity}'
                                    '${item.refunded ? ' (reembolsado)' : ''}',
                                  ),
                                ),
                                Text(formatCop(item.unitPrice * item.quantity)),
                              ],
                            ),
                          ),
                        if (purchase.isExpired)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(
                              'Esta compra venció: ya no se puede entregar.',
                              style: text.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  AppButton(
                    onPressed:
                        purchase.displayStatus == PurchaseStatus.pendingClaim
                        ? () => _claim(purchase)
                        : null,
                    icon: Icons.check_circle_outline,
                    child: const Text('Marcar como entregado'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pago Nequi de una compra que el personal debe verificar en su propio
/// Nequi: si el dinero llegó lo confirma (y el cliente recibe su código) y
/// si no, lo rechaza.
class _PendingPaymentCard extends StatelessWidget {
  final Purchase purchase;

  const _PendingPaymentCard({required this.purchase});

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

  Future<void> _confirm(BuildContext context, PaymentRecord payment) async {
    final repo = context.read<PurchaseRepository>();
    final ok = await AppDialog.confirm(
      context,
      title: 'Confirmar pago',
      message:
          'Confirma solo si ya ves ${formatCop(payment.amount)} en tu Nequi '
          'con la referencia ${payment.reference ?? '—'}. El cliente '
          'recibirá su código de reclamo.',
      confirmLabel: 'Sí, lo recibí',
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => repo.confirmPayment(purchase.id),
      'No se pudo confirmar',
    );
  }

  Future<void> _reject(BuildContext context) async {
    final repo = context.read<PurchaseRepository>();
    final ok = await AppDialog.confirm(
      context,
      title: 'Rechazar pago',
      message:
          'La compra quedará como fallida. Hazlo solo si el dinero no llegó '
          'a tu Nequi.',
      confirmLabel: 'Rechazar pago',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await _run(
      context,
      () => repo.rejectPayment(purchase.id),
      'No se pudo rechazar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaymentStreamBuilder(
      paymentId: purchase.paymentId,
      builder: (context, payment) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(purchase.itemsLabel, style: text.titleSmall),
            const SizedBox(height: AppSpace.xs),
            if (purchase.createdAt != null)
              Text(dateTimeLabel(purchase.createdAt!), style: text.bodySmall),
            const SizedBox(height: AppSpace.sm),
            if (payment == null)
              Text('Cargando pago…', style: text.bodySmall)
            else
              PaymentStatusLine(payment: payment),
            if (payment != null && payment.isPending) ...[
              const SizedBox(height: AppSpace.md),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.xs,
                runSpacing: AppSpace.xs,
                children: [
                  AppButton(
                    expand: false,
                    variant: AppButtonVariant.text,
                    onPressed: () => _reject(context),
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
                    onPressed: () => _confirm(context, payment),
                    child: const Text('Confirmar pago'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
