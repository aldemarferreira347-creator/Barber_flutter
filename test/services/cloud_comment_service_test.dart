import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/models/comment.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/cloud_comment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockStorageRepository extends Mock implements StorageRepository {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockFirebaseFirestore firestore;
  late MockStorageRepository storage;
  late CloudCommentService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    functions = MockFirebaseFunctions();
    firestore = MockFirebaseFirestore();
    storage = MockStorageRepository();
    service = CloudCommentService(storage: storage, functions: functions, firestore: firestore);
  });

  test('submitComment envía el payload y traduce el status devuelto', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('submitAppointmentComment')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'commentId': 'appt1', 'status': 'published'});

    final status = await service.submitComment(
      appointmentId: 'appt1',
      text: 'Excelente corte',
      photoUrl: 'https://x/1.jpg',
    );

    expect(status, CommentStatus.published);
    verify(
      () => callable.call<Map<String, dynamic>>({
        'appointmentId': 'appt1',
        'text': 'Excelente corte',
        'photoUrl': 'https://x/1.jpg',
      }),
    ).called(1);
  });

  test('submitComment devuelve rejected cuando el backend rechaza el comentario', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('submitAppointmentComment')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'commentId': 'appt1', 'status': 'rejected'});

    final status = await service.submitComment(appointmentId: 'appt1', text: 'grosería', photoUrl: null);

    expect(status, CommentStatus.rejected);
  });

  test('replyToComment envía commentId y replyText', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('replyToComment')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => MockHttpsCallableResult<Map<String, dynamic>>());

    await service.replyToComment(commentId: 'c1', replyText: 'Gracias por tu visita');

    verify(() => callable.call<Map<String, dynamic>>({'commentId': 'c1', 'replyText': 'Gracias por tu visita'}))
        .called(1);
  });

  test('uploadPhoto delega en StorageRepository con la ruta esperada', () async {
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'https://example.com/photo.png');
    final bytes = Uint8List.fromList([1, 2, 3]);

    final url = await service.uploadPhoto(appointmentId: 'appt1', fileName: 'photo.png', bytes: bytes);

    expect(url, 'https://example.com/photo.png');
    verify(() => storage.uploadBytes(path: 'comments/appt1/photo.png', bytes: bytes)).called(1);
  });

  test('watchPublishedByBarbershop traduce los documentos publicados, más recientes primero', () async {
    final collection = MockCollectionReference();
    final query1 = MockQuery();
    final query2 = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final doc1 = MockQueryDocumentSnapshot();
    final doc2 = MockQueryDocumentSnapshot();

    when(() => firestore.collection('comments')).thenReturn(collection);
    when(() => collection.where('barbershopId', isEqualTo: 'shop1')).thenReturn(query1);
    when(() => query1.where('status', isEqualTo: 'published')).thenReturn(query2);
    when(() => query2.snapshots()).thenAnswer((_) => Stream.value(querySnapshot));
    when(() => querySnapshot.docs).thenReturn([doc1, doc2]);
    when(() => doc1.id).thenReturn('appt1');
    when(() => doc1.data()).thenReturn({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': 'client1',
      'clientName': 'Ana',
      'text': 'Primero',
      'status': 'published',
    });
    when(() => doc2.id).thenReturn('appt2');
    when(() => doc2.data()).thenReturn({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': 'client2',
      'clientName': 'Beto',
      'text': 'Segundo',
      'status': 'published',
    });

    final comments = await service.watchPublishedByBarbershop('shop1').first;

    expect(comments, hasLength(2));
    // reversed: el último documento devuelto por Firestore aparece primero.
    expect(comments.first.appointmentId, 'appt2');
  });
}
