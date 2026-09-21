import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/purchase.dart';
import '../../repositories/purchase_repository.dart';
import '../../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

/// El barbero introduce el código de reclamo de una compra (spec 10.4),
/// revisa el checklist de productos y la marca como entregada.
class ClaimPurchaseView extends StatefulWidget {
  final String barbershopId;

  const ClaimPurchaseView({super.key, required this.barbershopId});

  @override
  State<ClaimPurchaseView> createState() => _ClaimPurchaseViewState();
}

class _ClaimPurchaseViewState extends State<ClaimPurchaseView> {
  final _codeController = TextEditingController();
  Purchase? _purchase;
  bool _searching = false;
  bool _claiming = false;
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
      final repo = context.read<PurchaseRepository>();
      final purchase = await repo.findByClaimCode(
        barbershopId: widget.barbershopId,
        claimCode: code,
      );
      setState(() => _purchase = purchase);
      if (purchase == null) {
        setState(
          () => _error =
              'No encontramos ninguna compra con ese código en esta barbería.',
        );
      }
    } catch (e) {
      setState(() => _error = 'No se pudo buscar el código: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _claim() async {
    final purchase = _purchase;
    if (purchase == null) return;
    setState(() => _claiming = true);
    try {
      await context.read<PurchaseRepository>().claimPurchase(purchase.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra marcada como entregada.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo marcar como entregada: $e');
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = _purchase;
    final canClaim =
        purchase != null && purchase.status == PurchaseStatus.pendingClaim;

    return Scaffold(
      appBar: AppBar(title: const Text('Reclamar compra')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Código de reclamo',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searching ? null : _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_searching) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            if (purchase != null) ...[
              Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              purchase.status.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '\$${purchase.totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        for (final item in purchase.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  item.refunded
                                      ? Icons.remove_circle_outline
                                      : Icons.check_box_outlined,
                                  size: 18,
                                  color: item.refunded
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.productName} ×${item.quantity}${item.refunded ? ' (reembolsado)' : ''}',
                                  ),
                                ),
                                Text(
                                  '\$${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: canClaim && !_claiming ? _claim : null,
                icon: _claiming ? null : Icons.check_circle_outline,
                child: _claiming
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Marcar como entregado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
