import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/service.dart';
import '../repositories/service_repository.dart';

class FirestoreServiceService implements ServiceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirestoreServiceService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _services(String barbershopId) =>
      _firestore.collection('barbershops').doc(barbershopId).collection('services');

  @override
  Stream<List<Service>> watchByBarbershop(String barbershopId) {
    return _services(barbershopId).orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Service.fromMap(doc.id, barbershopId, doc.data())).toList(),
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
  Future<String> uploadPhoto({required String barbershopId, required String fileName, required Uint8List bytes}) async {
    final ref = _storage.ref('barbershops/$barbershopId/services/$fileName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
