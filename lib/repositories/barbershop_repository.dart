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
  /// aprobación) pide que se le reconozca como Dueño (spec 12.1) vía la
  /// función en la nube `requestBarbershopOwnership` (Admin SDK).
  ///
  /// SIN USO ACTUALMENTE: esa función (como el resto de Cloud Functions
  /// del proyecto) requiere el plan Blaze, que este proyecto no tiene
  /// habilitado. [AddBarbershopView] hace la promoción de rol directo
  /// contra Firestore en su lugar (ver la rama dedicada en
  /// `firestore.rules`). Se deja esta ruta implementada para retomarla si
  /// el proyecto sube a Blaze más adelante.
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

  /// El admin confirma que la mensualidad de [id] fue pagada por una vía
  /// distinta al gateway (p.ej. verificada manualmente): la marca al día,
  /// reactiva la barbería si estaba bloqueada y arranca un nuevo ciclo de
  /// 30 días desde hoy — mismos efectos que [BarbershopRepository]'s
  /// `paySubscription` en Firestore, sin repetir el cobro (spec 12.5).
  Future<void> confirmPaymentReceived(String id);

  /// El admin bloquea [id] por falta de pago fuera del ciclo automático de
  /// vencimiento/gracia — mismos campos que toca el proceso automático al
  /// agotarse el período de gracia (spec 12.5/12.6). A diferencia de ese
  /// proceso, no cancela ni reembolsa citas ya pagadas; eso sigue
  /// resolviéndose por el backend cuando corresponde.
  Future<void> blockForNonPayment(String id);

  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule);

  Future<void> updateLocation(String id, double latitude, double longitude);
}
