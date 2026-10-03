import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/storage_repository.dart';
import '../utils/shared_stream.dart';

class FirestoreProductService implements ProductRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final StorageRepository _storage;

  FirestoreProductService({
    required this._storage,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _products(String barbershopId) =>
      _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('products');

  @override
  Stream<List<Product>> watchByBarbershop(String barbershopId) {
    return _shared.of<List<Product>>('watchByBarbershop:$barbershopId', () {
      return _products(barbershopId)
          .orderBy('name')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Product.fromMap(doc.id, barbershopId, doc.data()))
                .toList(),
          );
    });
  }

  @override
  Future<void> create(Product product) {
    return _products(product.barbershopId).add(product.toMap());
  }

  @override
  Future<void> update(Product product) {
    return _products(product.barbershopId).doc(product.id).update({
      'name': product.name,
      'description': product.description,
      'price': product.price,
      'photoUrl': product.photoUrl,
    });
  }

  @override
  Future<void> delete(String barbershopId, String productId) {
    return _products(barbershopId).doc(productId).delete();
  }

  @override
  Future<void> setActive(String barbershopId, String productId, bool active) {
    return _products(barbershopId).doc(productId).update({'active': active});
  }

  @override
  Future<String> uploadPhoto({
    required String barbershopId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _storage.uploadBytes(
      path: 'barbershops/$barbershopId/products/$fileName',
      bytes: bytes,
    );
  }
}
