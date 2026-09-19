import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/firestore_service_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageRepository extends Mock implements StorageRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  test('uploadPhoto delega en StorageRepository con la ruta esperada, sin tocar Firestore', () async {
    final storage = MockStorageRepository();
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'https://example.com/photo.png');

    final service = FirestoreServiceService(storage: storage, firestore: MockFirebaseFirestore());
    final bytes = Uint8List.fromList([1, 2, 3]);

    final url = await service.uploadPhoto(barbershopId: 'shop1', fileName: 'cut.png', bytes: bytes);

    expect(url, 'https://example.com/photo.png');
    verify(() => storage.uploadBytes(path: 'barbershops/shop1/services/cut.png', bytes: bytes)).called(1);
  });
}
