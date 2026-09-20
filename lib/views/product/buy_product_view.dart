import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../repositories/purchase_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

/// Compra directa de un producto (spec 10.3), sin necesidad de una cita.
/// Pide la cantidad, dispara el pago (Nequi, simulado por ahora) y sigue el
/// estado en vivo hasta mostrar el código de reclamo.
class BuyProductView extends StatefulWidget {
  final Product product;

  const BuyProductView({super.key, required this.product});

  @override
  State<BuyProductView> createState() => _BuyProductViewState();
}

class _BuyProductViewState extends State<BuyProductView> {
  int _quantity = 1;
  String? _purchaseId;
  bool _buying = false;
  String? _error;

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _error = null;
    });
    try {
      final repo = context.read<PurchaseRepository>();
      final id = await repo.createPurchase(
        barbershopId: widget.product.barbershopId,
        items: [
          PurchaseItemInput(productId: widget.product.id, quantity: _quantity),
        ],
      );
      setState(() => _purchaseId = id);
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar la compra: $e');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseId = _purchaseId;
    return Scaffold(
      appBar: AppBar(title: const Text('Comprar producto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: purchaseId == null ? _buildForm() : _buildStatus(purchaseId),
      ),
    );
  }

  Widget _buildForm() {
    final total = widget.product.price * _quantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.product.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        if ((widget.product.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.product.description!,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _quantity > 1
                  ? () => setState(() => _quantity--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_quantity',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => setState(() => _quantity++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Total: \$${total.toStringAsFixed(0)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        GradientButton(
          onPressed: _buying ? null : _buy,
          icon: _buying ? null : Icons.lock_outline,
          child: _buying
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Pagar con Nequi'),
        ),
      ],
    );
  }

  Widget _buildStatus(String purchaseId) {
    final repo = context.read<PurchaseRepository>();
    return StreamBuilder<Purchase?>(
      stream: repo.watchPurchase(purchaseId),
      builder: (context, snapshot) {
        final purchase = snapshot.data;
        if (purchase == null ||
            purchase.status == PurchaseStatus.pendingPayment) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Confirma el pago en tu app Nequi...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        if (purchase.status == PurchaseStatus.paymentFailed) {
          return const Center(
            child: Text(
              'El pago no pudo procesarse. Intenta de nuevo.',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 56,
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    curve: Curves.elasticOut,
                    duration: 700.ms,
                  )
                  .fadeIn(duration: 250.ms),
              const SizedBox(height: 16),
              const Text(
                '¡Compra confirmada!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Presenta este código en la barbería para reclamar tu producto:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        purchase.claimCode ?? '—',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    if (purchase.claimCode != null)
                      IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: 'Copiar código',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: purchase.claimCode!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Código copiado')),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tienes 24 horas para reclamarlo.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
