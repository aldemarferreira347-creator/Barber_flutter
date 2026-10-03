import 'dart:typed_data';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';

/// El dueño ya tiene [kMaxBarbershopDrafts] borradores: debe pagar o borrar
/// alguno antes de guardar otro.
class BarbershopDraftLimitException implements Exception {
  const BarbershopDraftLimitException();

  @override
  String toString() =>
      'Ya tienes $kMaxBarbershopDrafts borradores. Paga o elimina uno para '
      'poder guardar otro.';
}

/// Abstracción sobre la persistencia de barberías.
abstract class BarbershopRepository {
  Stream<List<Barbershop>> watchAll();

  /// Catálogo visible para clientes (spec 12.1/12.6): solo barberías
  /// aprobadas por el admin y activas.
  Stream<List<Barbershop>> watchApproved();

  Stream<List<Barbershop>> watchByOwner(String ownerId);

  Stream<Barbershop?> watchOne(String id);

  Future<String> create(Barbershop barbershop);

  /// Borradores del dueño (máximo [kMaxBarbershopDrafts]). Viven aparte de
  /// las barberías reales: nadie más los ve y no cuentan como barbería.
  Stream<List<Barbershop>> watchDraftsByOwner(String ownerId);

  /// Guarda un borrador nuevo en el primer cupo libre; lanza
  /// [BarbershopDraftLimitException] si ya están los 5 ocupados.
  Future<String> saveDraft(Barbershop draft);

  Future<void> updateDraft(String draftId, Barbershop draft);

  Future<void> deleteDraft(String draftId);

  Future<void> uploadDraftPhoto(
    String draftId, {
    required String fileName,
    required Uint8List bytes,
  });

  /// Registra el pago Nequi del primer mes ([reference] es la del
  /// comprobante) y convierte el borrador en barbería pendiente de revisión
  /// (el borrador se elimina). Devuelve el id de la barbería.
  Future<String> publishDraft(String draftId, {required String reference});

  /// Registra una barbería nueva pagando de una vez, sin pasar por borrador.
  /// Solo así (o con [publishDraft]) puede existir una barbería nueva: sin
  /// un pago registrado, firestore.rules rechaza la creación.
  Future<String> createPaid(Barbershop barbershop, {required String reference});

  /// Borra la barbería (Delete del CRUD del dueño). firestore.rules solo lo
  /// permite si no está aprobada o si ya se canceló su membresía (bloqueada);
  /// el admin puede siempre.
  Future<void> delete(String id);

  /// Edita los datos básicos de una barbería propia (nunca sus estados de
  /// aprobación, bloqueo o pago).
  Future<void> updateInfo(
    String id, {
    required String name,
    required String address,
    String? phone,
    String? email,
    String? description,
    String? nequiPhone,
  });

  /// El admin aprueba o rechaza la solicitud (spec 12.1/12.4): si aprueba,
  /// confirma el pago del registro, activa la barbería y arranca el primer
  /// ciclo de mensualidad; si rechaza, rechaza también ese pago.
  Future<void> resolveApproval(String id, {required bool approve});

  /// El dueño registra el pago Nequi de la mensualidad de ESA barbería
  /// (spec 12.5). Queda pendiente: la barbería se renueva cuando el admin lo
  /// confirma con [confirmSubscriptionPayment].
  Future<void> paySubscription(String id, {required String reference});

  /// El admin verificó el Nequi de la plataforma: aprueba el pago y renueva
  /// la mensualidad de la barbería, en una sola escritura.
  Future<void> confirmSubscriptionPayment(String paymentId);

  /// El dinero no llegó: el admin rechaza el pago de la mensualidad.
  Future<void> rejectSubscriptionPayment(String paymentId);

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

  /// El admin recibió la mensualidad de [id] por una vía sin comprobante en
  /// la app (p. ej. efectivo): la marca al día, reactiva la barbería si
  /// estaba bloqueada y arranca un nuevo ciclo de 30 días (spec 12.5).
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
