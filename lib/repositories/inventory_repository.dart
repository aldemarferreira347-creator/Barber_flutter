import '../models/purchase.dart';
import '../models/stock_movement.dart';

/// El stock pedido no alcanza para la salida, o el producto no lleva
/// inventario todavía.
class InsufficientStockException implements Exception {
  final String message;

  const InsufficientStockException(this.message);

  @override
  String toString() => message;
}

/// Abstracción sobre el inventario de una barbería: cuánto entra y cuánto
/// sale de cada producto, y quién lo hizo. Lo usan el dueño y los barberos
/// (no tocan precios: solo el stock).
abstract class InventoryRepository {
  /// Últimos movimientos de la barbería (más recientes primero).
  Stream<List<StockMovement>> watchMovements(String barbershopId);

  /// Registra una entrada o salida de [quantity] unidades de [productId] y
  /// actualiza el stock en la misma operación (transacción).
  ///
  /// - Un producto sin inventario (`stock == null`) empieza a llevarlo con
  ///   la primera entrada; una salida lanza [InsufficientStockException].
  /// - Una salida mayor al stock lanza [InsufficientStockException].
  Future<void> registerMovement({
    required String barbershopId,
    required String productId,
    required StockMovementType type,
    required int quantity,
    required StockReason reason,
    String? note,
  });

  /// Descuenta del inventario lo entregado en una compra reclamada. Solo
  /// afecta a los productos que llevan inventario y nunca baja de cero.
  /// Devuelve cuántos productos se descontaron.
  Future<int> registerPurchaseDelivery(Purchase purchase);
}
