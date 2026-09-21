import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';
import '../repositories/barbershop_repository.dart';
import '../repositories/storage_repository.dart';

class FirestoreBarbershopService implements BarbershopRepository {
  final FirebaseFirestore _firestore;
  final StorageRepository _storage;
  final FirebaseFunctions _functions;
  final Duration _simulatedApprovalDelay;

  FirestoreBarbershopService({
    required this._storage,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    // Configurable solo para que los tests no esperen el delay real — igual
    // que el parámetro `delayMs` de SimulatedNequiGateway en el backend.
    Duration? simulatedApprovalDelay,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
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
  Future<void> requestOwnership(String barbershopId) {
    return _functions
        .httpsCallable('requestBarbershopOwnership')
        .call<Map<String, dynamic>>({'barbershopId': barbershopId});
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

  // Placeholder hasta que el negocio defina el precio real de la mensualidad
  // — mismo valor que MONTHLY_FEE en functions/src/barbershops/subscriptionService.ts.
  static const _monthlyFee = 50000.0;
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

    final paymentRef = await _firestore.collection('payments').add({
      'payerId': shop.ownerId,
      'amount': _monthlyFee,
      'category': 'subscription',
      'relatedId': id,
      'description': 'Mensualidad de barbershops/$id',
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
