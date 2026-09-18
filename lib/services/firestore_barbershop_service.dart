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

  FirestoreBarbershopService({required this._storage, FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _barbershops => _firestore.collection('barbershops');

  @override
  Stream<List<Barbershop>> watchAll() {
    return _barbershops
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Barbershop.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<Barbershop>> watchApproved() {
    return _barbershops
        .where('approvalStatus', isEqualTo: BarbershopApprovalStatus.approved.value)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Barbershop.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<Barbershop>> watchByOwner(String ownerId) {
    return _barbershops
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Barbershop.fromMap(doc.id, doc.data())).toList());
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
  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule) {
    return _barbershops.doc(id).update({'schedule': weekScheduleToMap(schedule)});
  }

  @override
  Future<void> updateLocation(String id, double latitude, double longitude) {
    return _barbershops.doc(id).update({'location': GeoPoint(latitude, longitude)});
  }

  @override
  Future<void> uploadPhoto(String id, {required String fileName, required Uint8List bytes}) async {
    final url = await _storage.uploadBytes(path: 'barbershops/$id/profile/$fileName', bytes: bytes);
    await _barbershops.doc(id).update({'photoUrl': url});
  }

  @override
  Future<void> requestOwnership(String barbershopId) {
    return _functions.httpsCallable('requestBarbershopOwnership').call<Map<String, dynamic>>({
      'barbershopId': barbershopId,
    });
  }

  @override
  Future<void> resolveApproval(String id, {required bool approve}) {
    if (!approve) {
      return _barbershops.doc(id).update({'approvalStatus': BarbershopApprovalStatus.rejected.value});
    }
    // El primer ciclo de mensualidad arranca en la aprobación (30 días).
    return _barbershops.doc(id).update({
      'approvalStatus': BarbershopApprovalStatus.approved.value,
      'active': true,
      'paymentStatus': PaymentStatus.ok.value,
      'paymentDueDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
    });
  }

  @override
  Future<void> paySubscription(String id) {
    return _functions.httpsCallable('payBarbershopSubscription').call<Map<String, dynamic>>({'barbershopId': id});
  }

  @override
  Future<void> cancelSubscription(String id) {
    return _functions.httpsCallable('cancelBarbershopSubscription').call<Map<String, dynamic>>({'barbershopId': id});
  }
}
