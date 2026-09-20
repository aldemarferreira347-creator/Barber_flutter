import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service.dart';
import '../repositories/service_repository.dart';
import '../repositories/storage_repository.dart';

class FirestoreServiceService implements ServiceRepository {
  final FirebaseFirestore _firestore;
  final StorageRepository _storage;

  FirestoreServiceService({
    required this._storage,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _services(String barbershopId) =>
      _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('services');

  @override
  Stream<List<Service>> watchByBarbershop(String barbershopId) {
    return _services(barbershopId)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Service.fromMap(doc.id, barbershopId, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> create(Service service) {
    return _services(service.barbershopId).add(service.toMap());
  }

  @override
  Future<void> setActive(String barbershopId, String serviceId, bool active) {
    return _services(barbershopId).doc(serviceId).update({'active': active});
  }

  @override
  Future<String> uploadPhoto({
    required String barbershopId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _storage.uploadBytes(
      path: 'barbershops/$barbershopId/services/$fileName',
      bytes: bytes,
    );
  }
}
