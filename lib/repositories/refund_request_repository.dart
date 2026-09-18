import '../models/refund_request.dart';

/// Aprobación/rechazo de solicitudes de reembolso (spec 6.5) — reservado al
/// dueño de la barbería correspondiente (o al admin), resuelto en el
/// backend, que también procesa el reembolso real vía PaymentGateway.
abstract class RefundRequestRepository {
  Stream<List<RefundRequest>> watchByBarbershop(String barbershopId);

  Stream<List<RefundRequest>> watchByClient(String clientId);

  Future<void> resolve(String requestId, {required bool approve});
}
