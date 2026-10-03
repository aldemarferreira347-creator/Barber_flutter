import '../models/purchase.dart';

class PurchaseItemInput {
  final String productId;
  final int quantity;

  const PurchaseItemInput({required this.productId, required this.quantity});
}

/// Abstracción sobre compras de productos (spec 10.1–10.5). Cobro Nequi
/// manual: el comprador transfiere y registra la referencia; el personal de
/// la barbería verifica el dinero y entrega el código de reclamo.
abstract class PurchaseRepository {
  /// Crea la compra (vinculada a [appointmentId] si aplica, o directa si se
  /// omite) con su pago Nequi pendiente ([reference] es la del comprobante)
  /// y devuelve su id. El estado se sigue en vivo con [watchPurchase].
  Future<String> createPurchase({
    required String barbershopId,
    required List<PurchaseItemInput> items,
    required String reference,
    String? appointmentId,
  });

  /// El personal verificó el Nequi: aprueba el pago y deja la compra lista
  /// para reclamar (código y plazo de 24 h), en una sola escritura.
  Future<void> confirmPayment(String purchaseId);

  /// El dinero no llegó: rechaza el pago y la compra queda fallida.
  Future<void> rejectPayment(String purchaseId);

  Stream<Purchase?> watchPurchase(String purchaseId);

  Stream<List<Purchase>> watchByBuyer(String buyerId);

  Stream<List<Purchase>> watchByBarbershop(String barbershopId);

  /// El barbero busca una compra por su código de reclamo, dentro de su
  /// propia barbería.
  Future<Purchase?> findByClaimCode({
    required String barbershopId,
    required String claimCode,
  });

  /// El barbero marca la compra completa como reclamada. Falla si ya venció.
  Future<void> claimPurchase(String purchaseId);
}
