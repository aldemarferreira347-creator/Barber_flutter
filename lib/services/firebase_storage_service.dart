import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../repositories/storage_repository.dart';
import '../utils/image_content_type.dart';

class FirebaseStorageService implements StorageRepository {
  final FirebaseStorage _storage;

  FirebaseStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('La foto está vacía. Elige otra imagen.');
    }
    if (bytes.length >= kMaxPhotoBytes) {
      throw Exception('La foto pesa más de 5 MB. Elige una más liviana.');
    }
    final ref = _storage.ref(path);
    // Tipo explícito: sin él, en el teléfono el archivo sube como
    // "octet-stream", las reglas de Storage lo rechazan y luego
    // getDownloadURL falla con "el objeto no existe".
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: imageContentType(path)),
    );
    if (snapshot.state != TaskState.success) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'canceled',
        message: 'La foto no terminó de subirse.',
      );
    }
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) {
    return _storage.ref(path).delete();
  }
}
