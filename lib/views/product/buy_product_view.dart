import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/barbershop.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../repositories/barbershop_repository.dart';
import '../../repositories/purchase_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/error_state.dart';
import '../widgets/nequi_payment_sheet.dart';
import '../widgets/payment_status_line.dart';
import '../widgets/responsive_body.dart';
import 'claim_code_card.dart';

/// Compra directa de un producto (spec 10.3), sin necesidad de una cita.
/// El cliente elige la cantidad, paga por Nequi y registra su comprobante;
/// cuando la barbería confirma que recibió el dinero aparece aquí (y en
/// "Mis compras") el código para reclamar el producto.
class BuyProductView extends StatefulWidget {
  final Product product;

  const BuyProductView({super.key, required this.product});

  @override
  State<BuyProductView> createState() => _BuyProductViewState();
}

class _BuyProductViewState extends State<BuyProductView> {
  /// Tope por compra: evita errores de dedo.
  static const _maxQuantity = 20;

  late final Stream<Barbershop?> _shop = context
      .read<BarbershopRepository>()
      .watchOne(widget.product.barbershopId);

  int _quantity = 1;
  String? _purchaseId;
  bool _buying = false;
  String? _error;

  Future<void> _buy(Barbershop shop) async {
    final reference = await showNequiPaymentSheet(
      context,
      title: 'Pagar con Nequi',
      amount: widget.product.price * _quantity,
      payeeName: shop.name,
      payeePhone: shop.nequiPhone!,
    );
    if (reference == null || !mounted) return;

    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final id = await context.read<PurchaseRepository>().createPurchase(
        barbershopId: widget.product.barbershopId,
        items: [
          PurchaseItemInput(productId: widget.product.id, quantity: _quantity),
        ],
        reference: reference,
      );
      if (mounted) setState(() => _purchaseId = id);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar la compra: $e');
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseId = _purchaseId;
    return Scaffold(
      appBar: AppBar(title: const Text('Comprar producto')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        children: [
          ResponsiveBody(
            maxWidth: AppLayout.formWidth,
            child: purchaseId == null
                ? _buildForm()
                : _PurchaseStatus(purchaseId: purchaseId),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final text = Theme.of(context).textTheme;
    final total = widget.product.price * _quantity;
    return StreamBuilder<Barbershop?>(
      stream: _shop,
      builder: (context, snapshot) {
        final shop = snapshot.data;
        final canPay = shop != null && shop.acceptsNequi;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product.name, style: text.titleLarge),
                  if ((widget.product.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xs),
                    Text(widget.product.description!, style: text.secondary),
                  ],
                  const SizedBox(height: AppSpace.md),
                  Text(
                    formatCop(widget.product.price),
                    style: text.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            AppCard(
              child: Row(
                children: [
                  Expanded(child: Text('Cantidad', style: text.titleSmall)),
                  IconButton(
                    tooltip: 'Quitar una unidad',
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Agregar una unidad',
                    onPressed: _quantity < _maxQuantity
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                Expanded(child: Text('Total', style: text.secondary)),
                Text(formatCop(total), style: text.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            if (shop != null && !shop.acceptsNequi)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  'Esta barbería aún no recibe pagos por Nequi. Puedes '
                  'comprar este producto directamente en el local.',
                  style: text.secondary,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.readable(AppColors.error)),
                ),
              ),
            AppButton(
              onPressed: canPay ? () => _buy(shop) : null,
              icon: Icons.lock_outline,
              loading: _buying,
              child: const Text('Pagar con Nequi'),
            ),
          ],
        );
      },
    );
  }
}

/// Estado en vivo de la compra recién hecha: en verificación, fallida o
/// lista para reclamar con su código.
class _PurchaseStatus extends StatelessWidget {
  final String purchaseId;

  const _PurchaseStatus({required this.purchaseId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<PurchaseRepository>();
    final text = Theme.of(context).textTheme;
    return StreamBuilder<Purchase?>(
      stream: repo.watchPurchase(purchaseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorState(
            title: 'No pudimos cargar el estado de tu compra',
          );
        }
        final purchase = snapshot.data;
        if (purchase == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return switch (purchase.displayStatus) {
          PurchaseStatus.pendingPayment => _Message(
            icon: Icons.hourglass_top_outlined,
            color: AppColors.warning,
            title: 'Pago en verificación',
            body:
                'La barbería está confirmando que recibió tu transferencia. '
                'Cuando lo haga, tu código de reclamo aparecerá aquí y en '
                '"Mis compras".',
            footer: PaymentStreamBuilder(
              paymentId: purchase.paymentId,
              builder: (context, payment) => payment == null
                  ? const SizedBox.shrink()
                  : PaymentStatusLine(payment: payment),
            ),
          ),
          PurchaseStatus.paymentFailed => const _Message(
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            title: 'No pudimos confirmar tu pago',
            body:
                'La barbería no encontró tu transferencia. Revisa la '
                'referencia e inténtalo de nuevo, o consulta directamente '
                'en el local.',
          ),
          PurchaseStatus.expired => const _Message(
            icon: Icons.timer_off_outlined,
            color: AppColors.error,
            title: 'Compra vencida',
            body:
                'Pasaron más de 24 horas sin reclamarla. Comunícate con la '
                'barbería para resolverlo.',
          ),
          PurchaseStatus.claimed => const _Message(
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            title: 'Compra entregada',
            body: 'Ya reclamaste este producto. ¡Gracias!',
          ),
          PurchaseStatus.pendingClaim => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Message(
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                title: '¡Pago confirmado!',
                body:
                    'Presenta este código en la barbería para reclamar tu '
                    'producto.',
                footer: purchase.claimCode == null
                    ? null
                    : ClaimCodeCard(
                        code: purchase.claimCode!,
                        expiresAt: purchase.expiresAt,
                      ),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Tienes 24 horas para reclamarlo.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        };
      },
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? footer;

  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.xl),
        Icon(icon, size: 56, color: AppColors.readable(color)),
        const SizedBox(height: AppSpace.lg),
        Text(title, textAlign: TextAlign.center, style: text.titleLarge),
        const SizedBox(height: AppSpace.sm),
        Text(body, textAlign: TextAlign.center, style: text.secondary),
        if (footer != null) ...[const SizedBox(height: AppSpace.xl), footer!],
      ],
    );
  }
}
