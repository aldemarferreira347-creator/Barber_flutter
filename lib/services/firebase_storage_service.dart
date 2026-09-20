import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/storage_repository.dart';

class FirebaseStorageService implements StorageRepository {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref(path);
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) {
    return _storage.ref(path).delete();
  }
}
