import '../models/payment_record.dart';

/// Lectura de pagos Nequi manuales (payments/{id}). Crear y confirmar un
/// pago siempre va junto al documento que paga (cita, compra o barbería) y
/// por eso lo hace el repositorio de esa feature, en una sola escritura
/// atómica.
abstract class PaymentRepository {
  Stream<PaymentRecord?> watchPayment(String paymentId);

  /// Mensualidades que el admin todavía debe verificar (más antiguas
  /// primero).
  Stream<List<PaymentRecord>> watchPendingSubscriptions();

  /// Pagos de mensualidad de [shopId] hechos por [payerId] (el dueño),
  /// del más reciente al más antiguo.
  Stream<List<PaymentRecord>> watchSubscriptionPayments({
    required String payerId,
    required String shopId,
  });
}
