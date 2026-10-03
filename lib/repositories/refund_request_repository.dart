import '../models/payment_record.dart';
import '../models/refund_request.dart';

/// Aprobación/rechazo de solicitudes de reembolso (spec 6.5) — reservado al
/// dueño de la barbería correspondiente (o al admin). Como el cobro es
/// manual, quien aprueba devuelve el dinero por su cuenta (Nequi o
/// efectivo) y la app deja constancia del medio.
abstract class RefundRequestRepository {
  Stream<List<RefundRequest>> watchByBarbershop(String barbershopId);

  Stream<List<RefundRequest>> watchByClient(String clientId);

  /// Aprueba (cancela la cita, libera el horario y registra el reembolso) o
  /// rechaza la solicitud. [method] es obligatorio al aprobar una cita cuyo
  /// pago ya estaba confirmado.
  Future<void> resolve(
    String requestId, {
    required bool approve,
    RefundMethod? method,
  });
}
