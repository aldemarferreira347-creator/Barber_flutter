import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/models/refund_request.dart';
import 'package:barber/services/cloud_refund_request_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late CloudRefundRequestService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner1');
    service = CloudRefundRequestService(firestore: firestore, auth: auth);
  });

  test('resolve(approve: false) marca la solicitud rechazada, sin tocar la cita', () async {
    final requestsCollection = MockCollectionReference();
    final requestDocRef = MockDocumentReference();
    final requestSnap = MockDocumentSnapshot();

    when(() => firestore.collection('refundRequests')).thenReturn(requestsCollection);
    when(() => requestsCollection.doc('req1')).thenReturn(requestDocRef);
    when(() => requestDocRef.get()).thenAnswer((_) async => requestSnap);
    when(() => requestSnap.exists).thenReturn(true);
    when(() => requestSnap.data()).thenReturn({'appointmentId': 'appt1'});
    when(() => requestDocRef.update(any())).thenAnswer((_) async {});

    await service.resolve('req1', approve: false);

    final update = Map<String, dynamic>.from(verify(() => requestDocRef.update(captureAny())).captured.single as Map);
    expect(update['status'], 'rejected');
    expect(update['resolvedBy'], 'owner1');
  });

  test(
    'resolve(approve: true) cancela la cita, libera el horario y reembolsa el pago',
    () async {
      final requestsCollection = MockCollectionReference();
      final requestDocRef = MockDocumentReference();
      final requestSnap = MockDocumentSnapshot();
      final appointmentsCollection = MockCollectionReference();
      final appointmentDocRef = MockDocumentReference();
      final appointmentSnap = MockDocumentSnapshot();
      final slotsCollection = MockCollectionReference();
      final slotDocRef = MockDocumentReference();
      final paymentsCollection = MockCollectionReference();
      final paymentDocRef = MockDocumentReference();

      when(() => firestore.collection('refundRequests')).thenReturn(requestsCollection);
      when(() => requestsCollection.doc('req1')).thenReturn(requestDocRef);
      when(() => requestDocRef.get()).thenAnswer((_) async => requestSnap);
      when(() => requestSnap.exists).thenReturn(true);
      when(() => requestSnap.data()).thenReturn({'appointmentId': 'appt1'});
      when(() => requestDocRef.update(any())).thenAnswer((_) async {});

      when(() => firestore.collection('appointments')).thenReturn(appointmentsCollection);
      when(() => appointmentsCollection.doc('appt1')).thenReturn(appointmentDocRef);
      when(() => appointmentDocRef.get()).thenAnswer((_) async => appointmentSnap);
      when(() => appointmentSnap.exists).thenReturn(true);
      when(() => appointmentSnap.id).thenReturn('appt1');
      when(() => appointmentSnap.data()).thenReturn({
        'barbershopId': 'shop1',
        'barberId': 'barber1',
        'barberName': 'Beto',
        'clientId': 'client1',
        'clientName': 'Ana',
        'serviceId': 'svc1',
        'serviceName': 'Corte',
        'servicePrice': 20000,
        'durationMinutes': 30,
        'date': Timestamp.fromDate(DateTime.utc(2026, 6, 1, 15, 0)),
        'status': 'accepted',
        'paid': true,
        'paymentId': 'pay1',
      });
      when(() => appointmentDocRef.update(any())).thenAnswer((_) async {});

      when(() => firestore.collection('appointmentSlots')).thenReturn(slotsCollection);
      when(() => slotsCollection.doc('barber1_2026-06-01T15:00')).thenReturn(slotDocRef);
      when(() => slotDocRef.delete()).thenAnswer((_) async {});

      when(() => firestore.collection('payments')).thenReturn(paymentsCollection);
      when(() => paymentsCollection.doc('pay1')).thenReturn(paymentDocRef);
      when(() => paymentDocRef.update(any())).thenAnswer((_) async {});

      await service.resolve('req1', approve: true);

      final appointmentUpdate =
          Map<String, dynamic>.from(verify(() => appointmentDocRef.update(captureAny())).captured.single as Map);
      expect(appointmentUpdate['status'], 'cancelled');

      final requestUpdate =
          Map<String, dynamic>.from(verify(() => requestDocRef.update(captureAny())).captured.single as Map);
      expect(requestUpdate['status'], 'approved');
      expect(requestUpdate['resolvedBy'], 'owner1');

      verify(() => slotDocRef.delete()).called(1);

      final paymentUpdate =
          Map<String, dynamic>.from(verify(() => paymentDocRef.update(captureAny())).captured.single as Map);
      expect(paymentUpdate['status'], 'refunded');
      expect(paymentUpdate['refundedAmount'], 20000);
    },
  );

  test('watchByBarbershop traduce los documentos a RefundRequest', () async {
    final collection = MockCollectionReference();
    final query1 = MockQuery();
    final query2 = MockQuery();
    final querySnapshot = MockQuerySnapshot();
    final docSnapshot = MockQueryDocumentSnapshot();

    when(() => firestore.collection('refundRequests')).thenReturn(collection);
    when(() => collection.where('barbershopId', isEqualTo: 'shop1')).thenReturn(query1);
    when(() => query1.orderBy('createdAt', descending: true)).thenReturn(query2);
    when(() => query2.snapshots()).thenAnswer((_) => Stream.value(querySnapshot));
    when(() => querySnapshot.docs).thenReturn([docSnapshot]);
    when(() => docSnapshot.id).thenReturn('req1');
    when(() => docSnapshot.data()).thenReturn({
      'appointmentId': 'appt1',
      'barbershopId': 'shop1',
      'clientId': 'client1',
      'reason': 'Emergencia',
      'status': 'pending',
    });

    final requests = await service.watchByBarbershop('shop1').first;

    expect(requests, hasLength(1));
    expect(requests.first.status, RefundRequestStatus.pending);
  });
}
