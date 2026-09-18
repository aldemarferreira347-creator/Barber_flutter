/// Seguimiento de disponibilidad del barbero (spec 3.3): salida con
/// estimado propio y regreso. El límite para el aplazamiento automático de
/// sus reservas pagadas sale siempre de ese estimado — nunca un valor fijo.
abstract class BarberAvailabilityRepository {
  Future<void> markAway(int estimatedMinutes);

  Future<void> markReturned();
}
