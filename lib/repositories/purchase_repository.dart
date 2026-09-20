import '../models/purchase.dart';

class PurchaseItemInput {
  final String productId;
  final int quantity;

  const PurchaseItemInput({required this.productId, required this.quantity});
}

/// Abstracción sobre compras de productos (spec 10.1–10.5). Crear, reclamar
/// y reembolsar siempre pasan por el backend (recalcula precios, genera el
/// código de reclamo y llama a [PaymentGateway]) — el cliente solo lee.
abstract class PurchaseRepository {
  /// Crea la compra (vinculada a [appointmentId] si aplica, o directa si se
  /// omite) y devuelve su id. El estado se sigue en vivo con [watchPurchase].
  Future<String> createPurchase({
    required String barbershopId,
    required List<PurchaseItemInput> items,
    String? appointmentId,
  });

  Stream<Purchase?> watchPurchase(String purchaseId);

  Stream<List<Purchase>> watchByBuyer(String buyerId);

  Stream<List<Purchase>> watchByBarbershop(String barbershopId);

  /// El barbero busca una compra por su código de reclamo, dentro de su
  /// propia barbería.
  Future<Purchase?> findByClaimCode({
    required String barbershopId,
    required String claimCode,
  });

  /// El barbero marca la compra completa como reclamada.
  Future<void> claimPurchase(String purchaseId);

  /// Reembolso parcial por checklist de ítems (spec 6.5/10.5).
  Future<void> refundItems({
    required String purchaseId,
    required List<int> itemIndexes,
  });
}
