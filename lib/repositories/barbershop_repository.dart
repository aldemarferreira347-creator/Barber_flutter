import 'dart:typed_data';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';

/// Abstracción sobre la persistencia de barberías.
abstract class BarbershopRepository {
  Stream<List<Barbershop>> watchAll();

  /// Catálogo visible para clientes (spec 12.1/12.6): solo barberías
  /// aprobadas por el admin y activas.
  Stream<List<Barbershop>> watchApproved();

  Stream<List<Barbershop>> watchByOwner(String ownerId);

  Stream<Barbershop?> watchOne(String id);

  Future<String> create(Barbershop barbershop);

  /// El cliente que acaba de registrar [barbershopId] (pendiente de
  /// aprobación) pide que se le reconozca como Dueño (spec 12.1) — el
  /// backend es quien puede tocar su propio rol, nunca el cliente.
  Future<void> requestOwnership(String barbershopId);

  /// El admin aprueba o rechaza la solicitud (spec 12.1/12.4): si aprueba,
  /// activa la barbería y arranca el primer ciclo de mensualidad.
  Future<void> resolveApproval(String id, {required bool approve});

  /// El dueño paga/renueva la mensualidad de ESA barbería (spec 12.5).
  Future<void> paySubscription(String id);

  /// El dueño cancela la membresía directamente: bloquea de inmediato, sin
  /// período de gracia (spec 12.5).
  Future<void> cancelSubscription(String id);

  /// Sube la foto de portada de la barbería y guarda su URL.
  Future<void> uploadPhoto(
    String id, {
    required String fileName,
    required Uint8List bytes,
  });

  /// Bloqueo/desbloqueo selectivo — reservado al rol admin (impuesto también
  /// en firestore.rules, no solo en el cliente).
  Future<void> setActive(String id, bool active);

  /// Cambiar el estado de pago (ok/overdue/blocked) — reservado al rol
  /// admin (impuesto también en firestore.rules).
  Future<void> setPaymentStatus(String id, PaymentStatus status);

  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule);

  Future<void> updateLocation(String id, double latitude, double longitude);
}
