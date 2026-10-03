import 'package:barber/models/payment_record.dart';
import 'package:barber/models/refund_request.dart';
import 'package:barber/services/cloud_refund_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late CloudRefundRequestService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    final user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner1');
    service = CloudRefundRequestService(firestore: firestore, auth: auth);
  });

  Future<void> seed({String paymentStatus = 'approved'}) async {
    await firestore.collection('refundRequests').doc('req1').set({
      'appointmentId': 'appt1',
      'barbershopId': 'shop1',
      'clientId': 'client1',
      'reason': 'Emergencia',
      'status': 'pending',
    });
    await firestore.collection('appointments').doc('appt1').set({
      'barbershopId': 'shop1',
      'barberId': 'barber1',
      'barberName': 'Beto',
      'clientId': 'client1',
      'clientName': 'Ana',
      'serviceId': 'svc1',
      'serviceName': 'Corte',
      'servicePrice': 20000,
      'durationMinutes': 30,
      'date': Timestamp.fromDate(DateTime.utc(2026, 6, 1, 15)),
      'status': 'accepted',
      'paid': true,
      'paymentId': 'pay1',
    });
    await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-06-01T15:00')
        .set({'appointmentId': 'appt1', 'barberId': 'barber1'});
    await firestore.collection('payments').doc('pay1').set({
      'payerId': 'client1',
      'amount': 20000,
      'category': 'appointment',
      'relatedId': 'appt1',
      'status': paymentStatus,
    });
  }

  Future<Map<String, dynamic>> doc(String path) async =>
      (await firestore.doc(path).get()).data()!;

  test(
    'resolve(approve: false) marca la solicitud rechazada, sin tocar la cita',
    () async {
      await seed();

      await service.resolve('req1', approve: false);

      final request = await doc('refundRequests/req1');
      expect(request['status'], 'rejected');
      expect(request['resolvedBy'], 'owner1');
      expect((await doc('appointments/appt1'))['status'], 'accepted');
      expect((await doc('payments/pay1'))['status'], 'approved');
    },
  );

  test('resolve(approve: true) cancela la cita, libera el horario y registra el reembolso con su medio', () async {
    await seed();

    await service.resolve('req1', approve: true, method: RefundMethod.cash);

    expect((await doc('appointments/appt1'))['status'], 'cancelled');
    final request = await doc('refundRequests/req1');
    expect(request['status'], 'approved');
    expect(request['resolvedBy'], 'owner1');
    final slot = await firestore
        .doc('appointmentSlots/barber1_2026-06-01T15:00')
        .get();
    expect(slot.exists, isFalse);
    final payment = await doc('payments/pay1');
    expect(payment['status'], 'refunded');
    expect(payment['refundedAmount'], 20000);
    expect(payment['refundMethod'], 'cash');
  });

  test('aprobar un pago ya confirmado exige decir por qué medio se devolvió y no cambia nada si falta', () async {
    await seed();

    await expectLater(
      () => service.resolve('req1', approve: true),
      throwsA(anything),
    );

    expect((await doc('appointments/appt1'))['status'], 'accepted');
    expect((await doc('refundRequests/req1'))['status'], 'pending');
    expect((await doc('payments/pay1'))['status'], 'approved');
  });

  test('si el pago nunca se verificó, aprobar cancela la cita y da el pago por no recibido (sin medio)', () async {
    await seed(paymentStatus: 'pending');

    await service.resolve('req1', approve: true);

    expect((await doc('appointments/appt1'))['status'], 'cancelled');
    final payment = await doc('payments/pay1');
    expect(payment['status'], 'rejected');
    expect(payment.containsKey('refundedAmount'), isFalse);
  });

  test('una solicitud ya resuelta no se puede resolver otra vez', () async {
    await seed();
    await service.resolve('req1', approve: false);

    await expectLater(
      () => service.resolve('req1', approve: true, method: RefundMethod.nequi),
      throwsA(anything),
    );
    expect((await doc('appointments/appt1'))['status'], 'accepted');
  });

  test('watchByBarbershop traduce los documentos a RefundRequest', () async {
    await firestore.collection('refundRequests').doc('req1').set({
      'appointmentId': 'appt1',
      'barbershopId': 'shop1',
      'clientId': 'client1',
      'reason': 'Emergencia',
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    final requests = await service.watchByBarbershop('shop1').first;

    expect(requests, hasLength(1));
    expect(requests.first.status, RefundRequestStatus.pending);
  });
}
