import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/service.dart';
import '../repositories/service_repository.dart';
import '../repositories/storage_repository.dart';
import '../utils/image_content_type.dart';
import '../utils/shared_stream.dart';
import '../utils/parse_docs.dart';

class FirestoreServiceService implements ServiceRepository {
  final _shared = SharedStreams();

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
    return _shared.of<List<Service>>('watchByBarbershop:$barbershopId', () {
      return _services(barbershopId)
          .orderBy('name')
          .snapshots()
          .map(
            (snapshot) => parseDocs(
              snapshot.docs,
              (doc) => Service.fromMap(doc.id, barbershopId, doc.data()),
            ),
          );
    });
  }

  @override
  Future<String> create(Service service) async {
    final doc = await _services(service.barbershopId).add(service.toMap());
    return doc.id;
  }

  @override
  Future<void> update(Service service) {
    return _services(service.barbershopId).doc(service.id).update({
      'name': service.name,
      'description': service.description,
      'price': service.price,
      'durationMinutes': service.durationMinutes,
      'photoUrl': service.photoUrl,
    });
  }

  @override
  Future<void> delete(String barbershopId, String serviceId) {
    return _services(barbershopId).doc(serviceId).delete();
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
      path: 'barbershops/$barbershopId/services/${safeFileName(fileName)}',
      bytes: bytes,
    );
  }
}
