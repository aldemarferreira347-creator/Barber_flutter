import '../models/appointment.dart';

abstract class AppointmentRepository {
  /// Reserva SIN pago (spec 6.1): no bloquea el horario, cualquier cliente
  /// puede intentarlo aunque otro ya haya tomado esa hora.
  Future<String> create(Appointment appointment);

  /// Reserva PAGADA (spec 6.1/6.2): bloquea el horario con una transacción
  /// y registra el pago Nequi (pendiente, con la [reference] del
  /// comprobante) — si alguien más ya tomó el horario, lanza una excepción
  /// en vez de crear la cita. El personal verifica el dinero después con
  /// [confirmPayment] o [rejectPayment].
  Future<String> createPaid({
    required String barbershopId,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String clientName,
    required DateTime date,
    required String reference,
  });

  /// El personal verificó el Nequi: aprueba el pago y acepta la cita, en
  /// una sola escritura.
  Future<void> confirmPayment(String appointmentId);

  /// El dinero no llegó: rechaza el pago, cancela la cita y libera el
  /// horario, en una sola escritura.
  Future<void> rejectPayment(String appointmentId);

  /// Una cita en vivo (null si ya no existe o no se puede leer).
  Stream<Appointment?> watchOne(String appointmentId);

  Stream<List<Appointment>> watchByClient(String clientId);

  Stream<List<Appointment>> watchByBarber(String barberId);

  Stream<List<Appointment>> watchByBarbershop(String barbershopId);

  /// Citas de varias barberías a la vez (vista del Dueño con más de una),
  /// ordenadas por fecha. Cada barbería se consulta por separado para que
  /// firestore.rules verifique que quien pregunta es su dueño.
  Stream<List<Appointment>> watchByBarbershops(List<String> barbershopIds);

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
