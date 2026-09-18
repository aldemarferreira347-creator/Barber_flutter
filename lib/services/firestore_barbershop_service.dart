import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/barbershop.dart';
import '../models/day_schedule.dart';
import '../repositories/barbershop_repository.dart';

class FirestoreBarbershopService implements BarbershopRepository {
  final FirebaseFirestore _firestore;

  FirestoreBarbershopService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _barbershops => _firestore.collection('barbershops');

  @override
  Stream<List<Barbershop>> watchAll() {
    return _barbershops.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Barbershop.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<Barbershop>> watchByOwner(String ownerId) {
    return _barbershops.where('ownerId', isEqualTo: ownerId).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Barbershop.fromMap(doc.id, doc.data())).toList(),
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
  Future<void> updateSchedule(String id, Map<String, DaySchedule> schedule) {
    return _barbershops.doc(id).update({'schedule': weekScheduleToMap(schedule)});
  }

  @override
  Future<void> updateLocation(String id, double latitude, double longitude) {
    return _barbershops.doc(id).update({'location': GeoPoint(latitude, longitude)});
  }
}
