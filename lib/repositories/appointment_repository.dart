import '../models/appointment.dart';

abstract class AppointmentRepository {
  /// Reserva SIN pago (spec 6.1): no bloquea el horario, cualquier cliente
  /// puede intentarlo aunque otro ya haya tomado esa hora.
  Future<String> create(Appointment appointment);

  /// Reserva PAGADA (spec 6.1/6.2): bloquea el horario mediante una
  /// transacción en el backend antes de cobrar — si alguien más ya lo
  /// tomó, lanza una excepción en vez de crear la cita.
  Future<String> createPaid({
    required String barbershopId,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String clientName,
    required DateTime date,
  });

  Stream<List<Appointment>> watchByClient(String clientId);

  Stream<List<Appointment>> watchByBarber(String barberId);

  Stream<List<Appointment>> watchByBarbershop(String barbershopId);

  Future<void> setStatus(String id, AppointmentStatus status);

  /// Reprograma una cita SIN pago (escritura directa, sin bloqueo de
  /// horario — ver [postponePaid] para citas pagadas).
  Future<void> reschedule(String id, DateTime newDate);

  /// Posponer una cita PAGADA (spec 6.4): libera el horario viejo y
  /// reclama el nuevo con la misma transacción atómica de [createPaid].
  /// Puede llamarlo el cliente, el barbero asignado o el dueño de la barbería.
  Future<void> postponePaid(String appointmentId, DateTime newDate);

  /// El cliente, tras insistir en cancelar en vez de posponer, indica una
  /// justificación (spec 6.3) — no cancela nada todavía, queda pendiente
  /// de que el dueño la apruebe.
  Future<String> requestRefund({
    required String appointmentId,
    required String reason,
    String? purchaseId,
    List<int>? purchaseItemIndexes,
  });
}
