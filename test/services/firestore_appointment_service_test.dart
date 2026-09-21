import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/services/firestore_appointment_service.dart';
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
class MockTransaction extends Mock implements Transaction {}

class FakeDocumentReference extends Fake implements DocumentReference<Object?> {}

void main() {
  late MockFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late FirestoreAppointmentService service;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FakeDocumentReference());
  });

  setUp(() {
    firestore = MockFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('client1');
    service = FirestoreAppointmentService(
      firestore: firestore,
      auth: auth,
      simulatedApprovalDelay: Duration.zero,
    );
  });

  test(
    'createPaid bloquea el horario en una transacción, simula el pago y crea la cita',
    () async {
      final servicesCollection = MockCollectionReference();
      final serviceDocRef = MockDocumentReference();
      final serviceSnap = MockDocumentSnapshot();
      final shopsCollection = MockCollectionReference();
      final shopDocRef = MockDocumentReference();

      final appointmentsCollection = MockCollectionReference();
      final appointmentDocRef = MockDocumentReference();
      final paymentsCollection = MockCollectionReference();
      final paymentDocRef = MockDocumentReference();
      final slotsCollection = MockCollectionReference();
      final slotDocRef = MockDocumentReference();
      final tx = MockTransaction();
      final slotSnapInTx = MockDocumentSnapshot();

      when(() => firestore.collection('barbershops')).thenReturn(shopsCollection);
      when(() => shopsCollection.doc('shop1')).thenReturn(shopDocRef);
      when(() => shopDocRef.collection('services')).thenReturn(servicesCollection);
      when(() => servicesCollection.doc('svc1')).thenReturn(serviceDocRef);
      when(() => serviceDocRef.get()).thenAnswer((_) async => serviceSnap);
      when(() => serviceSnap.exists).thenReturn(true);
      when(() => serviceSnap.data()).thenReturn({
        'name': 'Corte',
        'price': 20000,
        'durationMinutes': 30,
        'active': true,
      });

      when(() => firestore.collection('appointmentSlots')).thenReturn(slotsCollection);
      when(() => slotsCollection.doc(any())).thenReturn(slotDocRef);

      when(() => firestore.collection('appointments')).thenReturn(appointmentsCollection);
      when(() => appointmentsCollection.doc()).thenReturn(appointmentDocRef);
      when(() => appointmentDocRef.id).thenReturn('appt1');

      when(() => firestore.collection('payments')).thenReturn(paymentsCollection);
      when(() => paymentsCollection.doc()).thenReturn(paymentDocRef);
      when(() => paymentDocRef.id).thenReturn('pay1');
      when(() => paymentDocRef.set(any())).thenAnswer((_) async {});
      when(() => paymentDocRef.update(any())).thenAnswer((_) async {});

      when(() => tx.get(slotDocRef)).thenAnswer((_) async => slotSnapInTx);
      when(() => slotSnapInTx.exists).thenReturn(false);
      when(() => tx.set(any(), any())).thenReturn(tx);
      when(
        () => firestore.runTransaction(any()),
      ).thenAnswer((invocation) async {
        final fn =
            invocation.positionalArguments[0] as Future<void> Function(Transaction);
        await fn(tx);
      });

      final date = DateTime.utc(2026, 6, 1, 15, 0);
      final id = await service.createPaid(
        barbershopId: 'shop1',
        barberId: 'barber1',
        barberName: 'Beto',
        serviceId: 'svc1',
        clientName: 'Ana',
        date: date,
      );

      expect(id, 'appt1');
      verify(() => slotsCollection.doc('barber1_2026-06-01T15:00')).called(1);
      verify(() => tx.get(slotDocRef)).called(1);
      verify(() => tx.set(slotDocRef, any())).called(1);
      verify(() => tx.set(appointmentDocRef, any())).called(1);

      final paymentCreate =
          Map<String, dynamic>.from(verify(() => paymentDocRef.set(captureAny())).captured.single as Map);
      expect(paymentCreate['payerId'], 'client1');
      expect(paymentCreate['amount'], 20000);
      expect(paymentCreate['category'], 'appointment');
      expect(paymentCreate['relatedId'], 'appt1');
      expect(paymentCreate['status'], 'pending');

      final paymentResolve =
          Map<String, dynamic>.from(verify(() => paymentDocRef.update(captureAny())).captured.single as Map);
      expect(paymentResolve['status'], 'approved');
    },
  );

  test(
    'createPaid rechaza el pago simulado y no crea la cita si el horario ya está tomado',
    () async {
      final servicesCollection = MockCollectionReference();
      final serviceDocRef = MockDocumentReference();
      final serviceSnap = MockDocumentSnapshot();
      final shopsCollection = MockCollectionReference();
      final shopDocRef = MockDocumentReference();

      final appointmentsCollection = MockCollectionReference();
      final appointmentDocRef = MockDocumentReference();
      final paymentsCollection = MockCollectionReference();
      final paymentDocRef = MockDocumentReference();
      final slotsCollection = MockCollectionReference();
      final slotDocRef = MockDocumentReference();
      final tx = MockTransaction();
      final slotSnapInTx = MockDocumentSnapshot();

      when(() => firestore.collection('barbershops')).thenReturn(shopsCollection);
      when(() => shopsCollection.doc('shop1')).thenReturn(shopDocRef);
      when(() => shopDocRef.collection('services')).thenReturn(servicesCollection);
      when(() => servicesCollection.doc('svc1')).thenReturn(serviceDocRef);
      when(() => serviceDocRef.get()).thenAnswer((_) async => serviceSnap);
      when(() => serviceSnap.exists).thenReturn(true);
      when(() => serviceSnap.data()).thenReturn({
        'name': 'Corte',
        'price': 20000,
        'durationMinutes': 30,
        'active': true,
      });

      when(() => firestore.collection('appointmentSlots')).thenReturn(slotsCollection);
      when(() => slotsCollection.doc(any())).thenReturn(slotDocRef);
      when(() => firestore.collection('appointments')).thenReturn(appointmentsCollection);
      when(() => appointmentsCollection.doc()).thenReturn(appointmentDocRef);
      when(() => appointmentDocRef.id).thenReturn('appt1');
      when(() => firestore.collection('payments')).thenReturn(paymentsCollection);
      when(() => paymentsCollection.doc()).thenReturn(paymentDocRef);
      when(() => paymentDocRef.id).thenReturn('pay1');
      when(() => paymentDocRef.set(any())).thenAnswer((_) async {});
      when(() => paymentDocRef.update(any())).thenAnswer((_) async {});

      when(() => tx.get(slotDocRef)).thenAnswer((_) async => slotSnapInTx);
      // El horario ya está tomado.
      when(() => slotSnapInTx.exists).thenReturn(true);
      when(
        () => firestore.runTransaction(any()),
      ).thenAnswer((invocation) async {
        final fn =
            invocation.positionalArguments[0] as Future<void> Function(Transaction);
        await fn(tx);
      });

      final date = DateTime.utc(2026, 6, 1, 15, 0);
      await expectLater(
        () => service.createPaid(
          barbershopId: 'shop1',
          barberId: 'barber1',
          barberName: 'Beto',
          serviceId: 'svc1',
          clientName: 'Ana',
          date: date,
        ),
        throwsA(anything),
      );

      verifyNever(() => tx.set(appointmentDocRef, any()));
      final paymentReject =
          Map<String, dynamic>.from(verify(() => paymentDocRef.update(captureAny())).captured.single as Map);
      expect(paymentReject['status'], 'rejected');
    },
  );

  test('postponePaid libera el horario viejo y reclama el nuevo en una transacción', () async {
    final appointmentsCollection = MockCollectionReference();
    final appointmentDocRef = MockDocumentReference();
    final appointmentSnap = MockDocumentSnapshot();
    final slotsCollection = MockCollectionReference();
    final oldSlotRef = MockDocumentReference();
    final newSlotRef = MockDocumentReference();
    final tx = MockTransaction();
    final newSlotSnapInTx = MockDocumentSnapshot();

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
    });

    when(() => firestore.collection('appointmentSlots')).thenReturn(slotsCollection);
    when(() => slotsCollection.doc('barber1_2026-06-01T15:00')).thenReturn(oldSlotRef);
    when(() => slotsCollection.doc('barber1_2026-06-02T15:00')).thenReturn(newSlotRef);
    when(() => tx.get(newSlotRef)).thenAnswer((_) async => newSlotSnapInTx);
    when(() => newSlotSnapInTx.exists).thenReturn(false);
    when(() => tx.delete(any())).thenReturn(tx);
    when(() => tx.set(any(), any())).thenReturn(tx);
    when(() => tx.update(any(), any())).thenReturn(tx);
    when(
      () => firestore.runTransaction(any()),
    ).thenAnswer((invocation) async {
      final fn = invocation.positionalArguments[0] as Future<void> Function(Transaction);
      await fn(tx);
    });

    final newDate = DateTime.utc(2026, 6, 2, 15, 0);
    await service.postponePaid('appt1', newDate);

    verify(() => tx.delete(oldSlotRef)).called(1);
    verify(() => tx.set(newSlotRef, any())).called(1);
    final appointmentUpdate =
        Map<String, dynamic>.from(verify(() => tx.update(appointmentDocRef, captureAny())).captured.single as Map);
    expect(appointmentUpdate['status'], 'postponed');
    expect((appointmentUpdate['date'] as Timestamp).toDate(), newDate);
  });

  test('requestRefund crea la solicitud con la justificación y devuelve su id', () async {
    final appointmentsCollection = MockCollectionReference();
    final appointmentDocRef = MockDocumentReference();
    final appointmentSnap = MockDocumentSnapshot();
    final requestsCollection = MockCollectionReference();
    final requestDocRef = MockDocumentReference();

    when(() => firestore.collection('appointments')).thenReturn(appointmentsCollection);
    when(() => appointmentsCollection.doc('appt1')).thenReturn(appointmentDocRef);
    when(() => appointmentDocRef.get()).thenAnswer((_) async => appointmentSnap);
    when(() => appointmentSnap.exists).thenReturn(true);
    when(() => appointmentSnap.data()).thenReturn({'barbershopId': 'shop1'});

    when(() => firestore.collection('refundRequests')).thenReturn(requestsCollection);
    when(() => requestsCollection.add(any())).thenAnswer((_) async => requestDocRef);
    when(() => requestDocRef.id).thenReturn('req1');

    final id = await service.requestRefund(appointmentId: 'appt1', reason: 'Emergencia');

    expect(id, 'req1');
    final created = Map<String, dynamic>.from(verify(() => requestsCollection.add(captureAny())).captured.single as Map);
    expect(created['appointmentId'], 'appt1');
    expect(created['barbershopId'], 'shop1');
    expect(created['clientId'], 'client1');
    expect(created['reason'], 'Emergencia');
    expect(created['status'], 'pending');
  });
}
