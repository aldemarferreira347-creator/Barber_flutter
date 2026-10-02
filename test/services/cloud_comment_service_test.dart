import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/models/comment.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/cloud_comment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockStorageRepository extends Mock implements StorageRepository {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late MockStorageRepository storage;
  late CloudCommentService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    storage = MockStorageRepository();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('client1');
    service = CloudCommentService(storage: storage, firestore: firestore, auth: auth);
  });

  Future<void> seedAppointment({
    bool paid = true,
    String status = 'completed',
    String clientId = 'client1',
  }) {
    return firestore.collection('appointments').doc('appt1').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': clientId,
      'clientName': 'Ana',
      'paid': paid,
      'status': status,
    });
  }

  test('submitComment publica un comentario sin lenguaje ofensivo', () async {
    await seedAppointment();

    final status = await service.submitComment(
      appointmentId: 'appt1',
      text: 'Excelente corte, muy puntual',
      photoUrl: 'https://x/1.jpg',
    );

    expect(status, CommentStatus.published);
    final doc = (await firestore.collection('comments').doc('appt1').get()).data()!;
    expect(doc['status'], 'published');
    expect(doc['barbershopId'], 'shop1');
    expect(doc['barberId'], 'barber1');
    expect(doc['clientId'], 'client1');
    expect(doc['clientName'], 'Ana');
    expect(doc['text'], 'Excelente corte, muy puntual');
    expect(doc['photoUrl'], 'https://x/1.jpg');
  });

  test('submitComment rechaza (pero guarda) un comentario con lenguaje ofensivo', () async {
    await seedAppointment();

    final status = await service.submitComment(appointmentId: 'appt1', text: 'el barbero es un idiota');

    expect(status, CommentStatus.rejected);
    final doc = (await firestore.collection('comments').doc('appt1').get()).data()!;
    expect(doc['status'], 'rejected');
  });

  test('submitComment detecta groserías con leetspeak y letras repetidas', () async {
    await seedAppointment();

    final status = await service.submitComment(appointmentId: 'appt1', text: 'que p3ndejooo');

    expect(status, CommentStatus.rejected);
  });

  test('submitComment rechaza comentar la cita de otro cliente', () async {
    await seedAppointment(clientId: 'other-client');

    await expectLater(
      () => service.submitComment(appointmentId: 'appt1', text: 'Buen servicio'),
      throwsA(anything),
    );
  });

  test('submitComment rechaza una cita no pagada o no completada', () async {
    await seedAppointment(status: 'accepted');

    await expectLater(
      () => service.submitComment(appointmentId: 'appt1', text: 'Buen servicio'),
      throwsA(anything),
    );
  });

  test('replyToComment guarda la respuesta del personal', () async {
    await firestore.collection('comments').doc('c1').set({
      'barbershopId': 'shop1',
      'status': 'published',
      'replyText': null,
    });
    when(() => user.uid).thenReturn('barber1');

    await service.replyToComment(commentId: 'c1', replyText: 'Gracias por tu visita');

    final doc = (await firestore.collection('comments').doc('c1').get()).data()!;
    expect(doc['replyText'], 'Gracias por tu visita');
    expect(doc['repliedByBarberId'], 'barber1');
  });

  test('replyToComment rechaza una respuesta con lenguaje ofensivo', () async {
    await firestore.collection('comments').doc('c1').set({
      'barbershopId': 'shop1',
      'status': 'published',
      'replyText': null,
    });

    await expectLater(
      () => service.replyToComment(commentId: 'c1', replyText: 'puto cliente'),
      throwsA(anything),
    );
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
    await firestore.collection('comments').doc('appt1').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': 'client1',
      'clientName': 'Ana',
      'text': 'Primero',
      'status': 'published',
    });
    await firestore.collection('comments').doc('appt2').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': 'client2',
      'clientName': 'Beto',
      'text': 'Segundo',
      'status': 'published',
    });
    await firestore.collection('comments').doc('appt3').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'clientId': 'client3',
      'clientName': 'Caro',
      'text': 'Rechazado',
      'status': 'rejected',
    });

    final comments = await service.watchPublishedByBarbershop('shop1').first;

    expect(comments, hasLength(2));
    expect(comments.map((c) => c.appointmentId), containsAll(['appt1', 'appt2']));
  });
}
