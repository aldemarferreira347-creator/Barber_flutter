import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/firestore_barbershop_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageRepository extends Mock implements StorageRepository {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  test('uploadPhoto sube la foto y guarda su URL en el documento', () async {
    final storage = MockStorageRepository();
    final firestore = MockFirebaseFirestore();
    final collection = MockCollectionReference();
    final docRef = MockDocumentReference();

    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'https://example.com/shop.png');
    when(() => firestore.collection('barbershops')).thenReturn(collection);
    when(() => collection.doc('shop1')).thenReturn(docRef);
    when(() => docRef.update(any())).thenAnswer((_) async {});

    final service = FirestoreBarbershopService(storage: storage, firestore: firestore);
    final bytes = Uint8List.fromList([1, 2, 3]);

    await service.uploadPhoto('shop1', fileName: 'cover.png', bytes: bytes);

    verify(() => storage.uploadBytes(path: 'barbershops/shop1/profile/cover.png', bytes: bytes)).called(1);
    verify(() => docRef.update({'photoUrl': 'https://example.com/shop.png'})).called(1);
  });
}
