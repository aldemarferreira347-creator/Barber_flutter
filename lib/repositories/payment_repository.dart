import '../models/payment_record.dart';

/// Abstracción sobre la pasarela de pago. Toda cita pagada, compra de
/// producto o mensualidad pasa por esta misma interfaz — así ninguna de
/// esas features conoce los detalles de Nequi, y cambiar de pasarela en el
/// futuro solo requeriría una nueva implementación de esta clase.
abstract class PaymentGateway {
  /// Crea la solicitud de pago y devuelve el id del registro creado. El
  /// usuario la aprueba desde su propia app Nequi; el estado final se seguirá
  /// en vivo con [watchPayment] (pending -> approved/rejected).
  Future<String> requestPayment({
    required double amount,
    required PaymentCategory category,
    required String relatedId,
    String? description,
  });

  Stream<PaymentRecord?> watchPayment(String paymentId);

  /// Reembolsa total (si se omite [amount]) o parcialmente un pago ya
  /// aprobado.
  Future<void> refund(String paymentId, {double? amount});
}
