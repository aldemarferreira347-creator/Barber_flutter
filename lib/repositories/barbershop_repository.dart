import '../models/barbershop.dart';
import '../models/day_schedule.dart';

/// Abstracción sobre la persistencia de barberías.
abstract class BarbershopRepository {
  Stream<List<Barbershop>> watchAll();

  Stream<List<Barbershop>> watchByOwner(String ownerId);

  Stream<Barbershop?> watchOne(String id);

  Future<String> create(Barbershop barbershop);

  /// Bloqueo/desbloqueo selectivo — reservado al rol admin (impuesto también
  /// en firestore.rules, no solo en el cliente).
  Future<void> setActive(String id, bool active);

  /// Cambiar el estado de pago (ok/overdue/blocked) — reservado al rol
  /// admin (impuesto también en firestore.rules).
  Future<void> setPaymentStatus(String id, PaymentStatus status);

  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule);

  Future<void> updateLocation(String id, double latitude, double longitude);
}
