import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';
import '../repositories/barbershop_repository.dart';
import '../repositories/storage_repository.dart';

class FirestoreBarbershopService implements BarbershopRepository {
  final FirebaseFirestore _firestore;
  final StorageRepository _storage;
  final Duration _simulatedApprovalDelay;

  FirestoreBarbershopService({
    required this._storage,
    FirebaseFirestore? firestore,
    // Configurable solo para que los tests no esperen el delay real — igual
    // que el parámetro `delayMs` de SimulatedNequiGateway en el backend.
    Duration? simulatedApprovalDelay,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _simulatedApprovalDelay =
           simulatedApprovalDelay ?? const Duration(milliseconds: 1500);

  CollectionReference<Map<String, dynamic>> get _barbershops =>
      _firestore.collection('barbershops');

  @override
  Stream<List<Barbershop>> watchAll() {
    return _barbershops
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Barbershop>> watchApproved() {
    return _barbershops
        .where(
          'approvalStatus',
          isEqualTo: BarbershopApprovalStatus.approved.value,
        )
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Barbershop>> watchByOwner(String ownerId) {
    return _barbershops
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<Barbershop?> watchOne(String id) {
    return _barbershops.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return Barbershop.fromMap(doc.id, data);
    });
  }

  @override
  Future<String> create(Barbershop barbershop) async {
    final doc = await _barbershops.add(barbershop.toMap());
    return doc.id;
  }

  CollectionReference<Map<String, dynamic>> get _drafts =>
      _firestore.collection('barbershopDrafts');

  @override
  Stream<List<Barbershop>> watchDraftsByOwner(String ownerId) {
    return _drafts
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Barbershop.fromDraftMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<String> saveDraft(Barbershop draft) async {
    // Los ids son `{uid}_{1..5}` y firestore.rules solo deja crear esos
    // cinco: el tope de borradores no depende de este cliente. Cada cupo se
    // reclama en una transacción para que dos guardados simultáneos no
    // pisen el mismo borrador.
    for (var slot = 1; slot <= kMaxBarbershopDrafts; slot++) {
      final ref = _drafts.doc('${draft.ownerId}_$slot');
      final claimed = await _firestore.runTransaction<bool>((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          ...draft.toDraftMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (claimed) return ref.id;
    }
    throw const BarbershopDraftLimitException();
  }

  @override
  Future<void> updateDraft(String draftId, Barbershop draft) {
    return _drafts.doc(draftId).update(draft.toDraftMap());
  }

  @override
  Future<void> deleteDraft(String draftId) {
    return _drafts.doc(draftId).delete();
  }

  @override
  Future<void> uploadDraftPhoto(
    String draftId, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final url = await _storage.uploadBytes(
      path: 'barbershopDrafts/$draftId/profile/$fileName',
      bytes: bytes,
    );
    await _drafts.doc(draftId).update({'photoUrl': url});
  }

  @override
  Future<String> publishDraft(String draftId) async {
    final snap = await _drafts.doc(draftId).get();
    final data = snap.data();
    if (data == null) throw Exception('El borrador ya no existe.');
    return _registerPaid(Barbershop.fromDraftMap(snap.id, data), draftId);
  }

  @override
  Future<String> createPaid(Barbershop barbershop) {
    return _registerPaid(barbershop, null);
  }

  /// Cobro simulado de [kBarbershopMonthlyFee]: crea el pago 'pendiente', espera
  /// y lo marca 'aprobado' (lo que firestore.rules exige para registrar o
  /// renovar). Devuelve el id del pago.
  Future<String> _chargeSubscription({
    required String payerId,
    required String relatedId,
    required String description,
  }) async {
    final paymentRef = await _firestore.collection('payments').add({
      'payerId': payerId,
      'amount': kBarbershopMonthlyFee,
      'category': 'subscription',
      'relatedId': relatedId,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      'refundedAmount': null,
    });
    await Future<void>.delayed(_simulatedApprovalDelay);
    await paymentRef.update({
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    return paymentRef.id;
  }

  /// Cobra el registro y crea la barbería 'pending'. La pasarela sigue
  /// simulada (ver [paySubscription]); firestore.rules exige que el pago
  /// exista, sea del dueño, de categoría 'subscription', esté aprobado y
  /// apunte al id de esta barbería — sin eso no se puede crear.
  Future<String> _registerPaid(Barbershop shop, String? draftId) async {
    final shopRef = _barbershops.doc();
    final paymentId = await _chargeSubscription(
      payerId: shop.ownerId,
      relatedId: shopRef.id,
      description: 'Registro de barbershops/${shopRef.id}',
    );

    final batch = _firestore.batch();
    batch.set(shopRef, {
      ...shop.toMap(),
      'active': false,
      'approvalStatus': BarbershopApprovalStatus.pending.value,
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': null,
      'paymentId': paymentId,
    });
    if (draftId != null) batch.delete(_drafts.doc(draftId));
    await batch.commit();
    return shopRef.id;
  }

  @override
  Future<void> delete(String id) => _barbershops.doc(id).delete();

  @override
  Future<void> updateInfo(
    String id, {
    required String name,
    required String address,
    String? phone,
    String? email,
    String? description,
  }) {
    return _barbershops.doc(id).update({
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'description': description,
    });
  }

  @override
  Future<void> setActive(String id, bool active) {
    return _barbershops.doc(id).update({'active': active});
  }

  @override
  Future<void> setPaymentStatus(String id, PaymentStatus status) {
    return _barbershops.doc(id).update({'paymentStatus': status.value});
  }

  @override
  Future<void> confirmPaymentReceived(String id) {
    // Mismos campos que actualiza payBarbershopSubscription en el backend
    // tras un cobro real (ver functions/src/barbershops/subscriptionService.ts).
    return _barbershops.doc(id).update({
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'active': true,
    });
  }

  @override
  Future<void> blockForNonPayment(String id) {
    // Mismos campos que actualiza el proceso automático de facturación al
    // agotarse el período de gracia (ver processBarbershopBilling).
    return _barbershops.doc(id).update({
      'paymentStatus': PaymentStatus.blocked.value,
      'active': false,
    });
  }

  @override
  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule) {
    return _barbershops.doc(id).update({
      'schedule': weekScheduleToMap(schedule),
    });
  }

  @override
  Future<void> updateLocation(String id, double latitude, double longitude) {
    return _barbershops.doc(id).update({
      'location': GeoPoint(latitude, longitude),
    });
  }

  @override
  Future<void> uploadPhoto(
    String id, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final url = await _storage.uploadBytes(
      path: 'barbershops/$id/profile/$fileName',
      bytes: bytes,
    );
    await _barbershops.doc(id).update({'photoUrl': url});
  }

  @override
  Future<void> resolveApproval(String id, {required bool approve}) {
    if (!approve) {
      return _barbershops.doc(id).update({
        'approvalStatus': BarbershopApprovalStatus.rejected.value,
      });
    }
    // El primer ciclo de mensualidad arranca en la aprobación (30 días).
    return _barbershops.doc(id).update({
      'approvalStatus': BarbershopApprovalStatus.approved.value,
      'active': true,
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });
  }

  static const _subscriptionPeriod = Duration(days: 30);

  @override
  Future<void> paySubscription(String id) async {
    // La pasarela sigue simulada (sin Nequi real ni plan Blaze para correr
    // payBarbershopSubscription en el backend): crea el registro de pago
    // "pendiente", espera un momento y lo marca "aprobado" — igual que
    // hacía SimulatedNequiGateway del lado del servidor — y luego renueva
    // la mensualidad de la barbería.
    final shopSnap = await _barbershops.doc(id).get();
    final shopData = shopSnap.data();
    if (shopData == null) throw Exception('La barbería no existe.');
    final shop = Barbershop.fromMap(shopSnap.id, shopData);

    await _chargeSubscription(
      payerId: shop.ownerId,
      relatedId: id,
      description: 'Mensualidad de barbershops/$id',
    );

    await _barbershops.doc(id).update({
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': Timestamp.fromDate(
        DateTime.now().add(_subscriptionPeriod),
      ),
      'active': true,
    });
  }

  @override
  Future<void> cancelSubscription(String id) {
    // Cancelación directa: bloquea de inmediato, sin período de gracia —
    // mismos campos que blockForNonPayment (ver ese método y
    // subscriptionService.ts, donde cancelSubscription también reutiliza
    // el mismo blockBarbershop() que usa el vencimiento automático).
    return blockForNonPayment(id);
  }
}
