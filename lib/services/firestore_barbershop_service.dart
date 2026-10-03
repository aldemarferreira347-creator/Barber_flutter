import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';
import '../models/payment_record.dart';
import '../models/platform_settings.dart';
import '../repositories/barbershop_repository.dart';
import '../repositories/storage_repository.dart';
import '../utils/stream_combine.dart';
import '../utils/shared_stream.dart';

class FirestoreBarbershopService implements BarbershopRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final StorageRepository _storage;

  final FirebaseAuth? _authOverride;

  FirestoreBarbershopService({
    required this._storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authOverride = auth;

  String? get _uid => (_authOverride ?? FirebaseAuth.instance).currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _barbershops =>
      _firestore.collection('barbershops');

  @override
  Stream<List<Barbershop>> watchAll() {
    return _shared.of<List<Barbershop>>('watchAll', () {
      return _barbershops
          .orderBy('name')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });
  }

  @override
  Stream<List<Barbershop>> watchApproved() {
    return _shared.of<List<Barbershop>>('watchApproved', () {
      // Solo las que pueden operar: aprobadas, activas y con la mensualidad
      // vigente o dentro de la gracia (la configura el admin). Se deriva de la
      // fecha porque ningún proceso del servidor bloquea por mora.
      final shops = _barbershops
          .where(
            'approvalStatus',
            isEqualTo: BarbershopApprovalStatus.approved.value,
          )
          .where('active', isEqualTo: true)
          .snapshots();
      return combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        DocumentSnapshot<Map<String, dynamic>>,
        List<Barbershop>
      >(shops, _settings.snapshots(), (snapshot, settingsDoc) {
        final graceDays = PlatformSettings.fromMap(settingsDoc.data())
            .graceDays;
        return [
          for (final doc in snapshot.docs)
            if (Barbershop.fromMap(
              doc.id,
              doc.data(),
            ).isOperational(graceDays: graceDays))
              Barbershop.fromMap(doc.id, doc.data()),
        ];
      });
    });
  }

  @override
  Stream<List<Barbershop>> watchByOwner(String ownerId) {
    return _shared.of<List<Barbershop>>('watchByOwner:$ownerId', () {
      return _barbershops
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Barbershop.fromMap(doc.id, doc.data()))
                .toList(),
          );
    });
  }

  @override
  Stream<Barbershop?> watchOne(String id) {
    return _shared.of<Barbershop?>('watchOne:$id', () {
      return _barbershops.doc(id).snapshots().map((doc) {
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        return Barbershop.fromMap(doc.id, data);
      });
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
    return _shared.of<List<Barbershop>>('watchDraftsByOwner:$ownerId', () {
      return _drafts
          .where('ownerId', isEqualTo: ownerId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Barbershop.fromDraftMap(doc.id, doc.data()))
                .toList(),
          );
    });
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
  Future<String> publishDraft(
    String draftId, {
    required String reference,
  }) async {
    final snap = await _drafts.doc(draftId).get();
    final data = snap.data();
    if (data == null) throw Exception('El borrador ya no existe.');
    return _registerPaid(
      Barbershop.fromDraftMap(snap.id, data),
      draftId,
      reference,
    );
  }

  @override
  Future<String> createPaid(
    Barbershop barbershop, {
    required String reference,
  }) {
    return _registerPaid(barbershop, null, reference);
  }

  DocumentReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('platformSettings').doc('main');

  /// Mensualidad vigente: la que configuró el admin o, mientras no haya
  /// configuración, la predeterminada (la misma que asumen las reglas).
  Future<double> _currentFee() async {
    final settings = PlatformSettings.fromMap((await _settings.get()).data());
    return settings.monthlyFee;
  }

  /// Registra el pago Nequi de la mensualidad: queda 'pending' con la
  /// referencia del comprobante hasta que el admin verifique su Nequi. No
  /// toca la barbería. Devuelve el id del pago.
  Future<String> _submitSubscriptionPayment({
    required String payerId,
    required String relatedId,
    required String description,
    required String reference,
  }) async {
    final paymentRef = await _firestore
        .collection('payments')
        .add(
          PaymentRecord.newPendingMap(
            payerId: payerId,
            amount: await _currentFee(),
            category: PaymentCategory.subscription,
            relatedId: relatedId,
            description: description,
            reference: reference,
          ),
        );
    return paymentRef.id;
  }

  /// Registra el pago de la primera mensualidad y crea la barbería
  /// 'pending'. firestore.rules exige que el pago exista, sea del dueño, de
  /// categoría 'subscription' y apunte al id de esta barbería. El admin
  /// verifica el dinero al aprobar la barbería ([resolveApproval]).
  Future<String> _registerPaid(
    Barbershop shop,
    String? draftId,
    String reference,
  ) async {
    final shopRef = _barbershops.doc();
    final paymentId = await _submitSubscriptionPayment(
      payerId: shop.ownerId,
      relatedId: shopRef.id,
      description: 'Registro de barbershops/${shopRef.id}',
      reference: reference,
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
    String? nequiPhone,
  }) {
    final nequi = normalizeNequiPhone(nequiPhone ?? '');
    return _barbershops.doc(id).update({
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'description': description,
      'nequiPhone': nequi.isEmpty ? null : nequi,
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
  Future<void> confirmPaymentReceived(String id) async {
    // El admin recibió la mensualidad por una vía sin comprobante en la app
    // (p. ej. efectivo): renueva igual que al confirmar un pago Nequi.
    await _barbershops.doc(id).update(await _renewalFields(id));
  }

  /// Campos de una barbería al día. El ciclo corre desde el vencimiento
  /// actual si todavía no pasó (pagar antes no regala ni quita días) o
  /// desde hoy si ya venció.
  Future<Map<String, dynamic>> _renewalFields(String shopId) async {
    final snap = await _barbershops.doc(shopId).get();
    final due = snap.data()?['paymentDueDate'];
    final now = DateTime.now();
    final base = due is Timestamp && due.toDate().isAfter(now)
        ? due.toDate()
        : now;
    return {
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': Timestamp.fromDate(base.add(_subscriptionPeriod)),
      'active': true,
    };
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

  Map<String, dynamic> _paymentResolution(PaymentIntentStatus status) => {
    'status': status.value,
    'resolvedAt': FieldValue.serverTimestamp(),
    'resolvedBy': _uid,
  };

  /// Referencia al pago de la mensualidad pendiente de [shopId] si lo hay.
  Future<DocumentReference<Map<String, dynamic>>?> _pendingRegistrationPayment(
    String shopId,
  ) async {
    final paymentId = (await _barbershops.doc(shopId).get())
        .data()?['paymentId'];
    if (paymentId is! String) return null;
    final ref = _firestore.collection('payments').doc(paymentId);
    final status = (await ref.get()).data()?['status'];
    return status == PaymentIntentStatus.pending.value ? ref : null;
  }

  @override
  Future<void> resolveApproval(String id, {required bool approve}) async {
    // Aprobar = el admin verificó en su Nequi el pago del registro y deja
    // la barbería visible; rechazar = no llegó el dinero (o la barbería no
    // procede). Las dos cosas se resuelven en la misma escritura.
    final payment = await _pendingRegistrationPayment(id);
    final batch = _firestore.batch();
    if (!approve) {
      batch.update(_barbershops.doc(id), {
        'approvalStatus': BarbershopApprovalStatus.rejected.value,
      });
      if (payment != null) {
        batch.update(payment, _paymentResolution(PaymentIntentStatus.rejected));
      }
    } else {
      // El primer ciclo de mensualidad arranca en la aprobación (30 días).
      batch.update(_barbershops.doc(id), {
        'approvalStatus': BarbershopApprovalStatus.approved.value,
        'active': true,
        'paymentStatus': PaymentStatus.ok.value,
        'paymentDueDate': Timestamp.fromDate(
          DateTime.now().add(_subscriptionPeriod),
        ),
      });
      if (payment != null) {
        batch.update(payment, _paymentResolution(PaymentIntentStatus.approved));
      }
    }
    await batch.commit();
  }

  static const _subscriptionPeriod = Duration(days: 30);

  @override
  Future<void> paySubscription(String id, {required String reference}) async {
    // El dueño transfirió a la plataforma y registra su comprobante: solo
    // se crea el pago pendiente. La barbería no cambia hasta que el admin
    // lo confirme ([confirmSubscriptionPayment]).
    final shopSnap = await _barbershops.doc(id).get();
    final shopData = shopSnap.data();
    if (shopData == null) throw Exception('La barbería no existe.');
    final shop = Barbershop.fromMap(shopSnap.id, shopData);

    await _submitSubscriptionPayment(
      payerId: shop.ownerId,
      relatedId: id,
      description: 'Mensualidad de barbershops/$id',
      reference: reference,
    );
  }

  @override
  Future<void> confirmSubscriptionPayment(String paymentId) async {
    final paymentRef = _firestore.collection('payments').doc(paymentId);
    final payment = (await paymentRef.get()).data();
    if (payment == null || payment['category'] != 'subscription') {
      throw Exception('Ese pago no es una mensualidad.');
    }
    if (payment['status'] != PaymentIntentStatus.pending.value) {
      throw Exception('Ese pago ya fue resuelto.');
    }
    final shopId = payment['relatedId'] as String;
    final shopRef = _barbershops.doc(shopId);
    final shop = (await shopRef.get()).data();
    if (shop == null) throw Exception('La barbería ya no existe.');

    final batch = _firestore.batch();
    batch.update(paymentRef, _paymentResolution(PaymentIntentStatus.approved));
    // Una barbería aún sin aprobar la aprueba el admin con [resolveApproval],
    // que también confirma este pago; aquí solo se renueva una aprobada.
    if (shop['approvalStatus'] == BarbershopApprovalStatus.approved.value) {
      batch.update(shopRef, await _renewalFields(shopId));
    }
    await batch.commit();
  }

  @override
  Future<void> rejectSubscriptionPayment(String paymentId) {
    return _firestore
        .collection('payments')
        .doc(paymentId)
        .update(_paymentResolution(PaymentIntentStatus.rejected));
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
