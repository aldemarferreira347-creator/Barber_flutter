import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber/services/firestore_appointment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// FirebaseAuth es un mock simple (solo se necesita currentUser.uid) —
// Firestore usa FakeFirebaseFirestore en vez de mocktail porque createPaid/
// postponePaid corren dentro de una transacción real (runTransaction), y
// mocktail no logra interceptar bien ese método genérico.
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;
  late FirestoreAppointmentService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('client1');
    service = FirestoreAppointmentService(firestore: firestore, auth: auth);
  });

  Future<void> seedService({bool active = true}) {
    return firestore
        .collection('barbershops')
        .doc('shop1')
        .collection('services')
        .doc('svc1')
        .set({
          'name': 'Corte',
          'price': 20000,
          'durationMinutes': 30,
          'active': active,
        });
  }

  test('createPaid bloquea el horario, registra el pago Nequi pendiente y crea la cita pagada', () async {
    await seedService();

    final date = DateTime.utc(2026, 6, 1, 15);
    final id = await service.createPaid(
      barbershopId: 'shop1',
      barberId: 'barber1',
      barberName: 'Beto',
      serviceId: 'svc1',
      clientName: 'Ana',
      date: date,
      reference: 'M1234567',
    );

    final appointmentSnap = await firestore
        .collection('appointments')
        .doc(id)
        .get();
    final appointment = appointmentSnap.data()!;
    expect(appointment['paid'], true);
    expect(appointment['status'], 'pending');
    expect(appointment['clientId'], 'client1');
    expect(appointment['servicePrice'], 20000);
    expect(appointment['serviceName'], 'Corte');

    final slotSnap = await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-06-01T15:00')
        .get();
    expect(slotSnap.exists, true);
    expect(slotSnap.data()!['appointmentId'], id);

    final paymentId = appointment['paymentId'] as String;
    final paymentSnap = await firestore
        .collection('payments')
        .doc(paymentId)
        .get();
    final payment = paymentSnap.data()!;
    // El dinero aún no se verificó: lo confirma el personal después.
    expect(payment['status'], 'pending');
    expect(payment['reference'], 'M1234567');
    expect(payment['method'], 'nequi');
    expect(payment['payerId'], 'client1');
    expect(payment['amount'], 20000);
    expect(payment['category'], 'appointment');
    expect(payment['relatedId'], id);
  });

  test(
    'createPaid falla y rechaza el pago si el horario ya está tomado',
    () async {
      await seedService();
      await firestore
          .collection('appointmentSlots')
          .doc('barber1_2026-06-01T15:00')
          .set({'appointmentId': 'other', 'barberId': 'barber1'});

      final date = DateTime.utc(2026, 6, 1, 15);
      await expectLater(
        () => service.createPaid(
          barbershopId: 'shop1',
          barberId: 'barber1',
          barberName: 'Beto',
          serviceId: 'svc1',
          clientName: 'Ana',
          date: date,
          reference: 'M1234567',
        ),
        throwsA(anything),
      );

      final appointments = await firestore.collection('appointments').get();
      expect(appointments.docs, isEmpty);

      final payments = await firestore.collection('payments').get();
      expect(payments.docs, hasLength(1));
      expect(payments.docs.first.data()['status'], 'rejected');
    },
  );

  test(
    'createPaid rechaza un servicio inactivo sin tocar el horario',
    () async {
      await seedService(active: false);

      await expectLater(
        () => service.createPaid(
          barbershopId: 'shop1',
          barberId: 'barber1',
          barberName: 'Beto',
          serviceId: 'svc1',
          clientName: 'Ana',
          date: DateTime.utc(2026, 6, 1, 15),
          reference: 'M1234567',
        ),
        throwsA(anything),
      );

      final slots = await firestore.collection('appointmentSlots').get();
      expect(slots.docs, isEmpty);
    },
  );

  group('verificación del pago por el personal', () {
    late String appointmentId;
    final date = DateTime.utc(2026, 6, 1, 15);

    setUp(() async {
      await seedService();
      appointmentId = await service.createPaid(
        barbershopId: 'shop1',
        barberId: 'barber1',
        barberName: 'Beto',
        serviceId: 'svc1',
        clientName: 'Ana',
        date: date,
        reference: 'M1234567',
      );
      // A partir de aquí actúa el personal de la barbería.
      when(() => user.uid).thenReturn('barber1');
    });

    Future<Map<String, dynamic>> payment() async {
      final appointment =
          (await firestore.collection('appointments').doc(appointmentId).get())
              .data()!;
      return (await firestore
              .collection('payments')
              .doc(appointment['paymentId'] as String)
              .get())
          .data()!;
    }

    test('confirmPayment aprueba el pago y acepta la cita', () async {
      await service.confirmPayment(appointmentId);

      final appointment =
          (await firestore.collection('appointments').doc(appointmentId).get())
              .data()!;
      expect(appointment['status'], 'accepted');
      final paid = await payment();
      expect(paid['status'], 'approved');
      expect(paid['resolvedBy'], 'barber1');
      expect(paid['resolvedAt'], isNotNull);
    });

    test(
      'rejectPayment rechaza el pago, cancela la cita y libera el horario',
      () async {
        await service.rejectPayment(appointmentId);

        final appointment =
            (await firestore
                    .collection('appointments')
                    .doc(appointmentId)
                    .get())
                .data()!;
        expect(appointment['status'], 'cancelled');
        expect((await payment())['status'], 'rejected');
        final slot = await firestore
            .collection('appointmentSlots')
            .doc('barber1_2026-06-01T15:00')
            .get();
        expect(slot.exists, isFalse);
      },
    );

    test('un pago ya resuelto no se vuelve a resolver', () async {
      await service.confirmPayment(appointmentId);
      await expectLater(
        () => service.rejectPayment(appointmentId),
        throwsA(anything),
      );
      expect((await payment())['status'], 'approved');
    });

    test('una cita sin pago no tiene nada que verificar', () async {
      await firestore.collection('appointments').doc('free').set({
        'barbershopId': 'shop1',
        'barberId': 'barber1',
        'clientId': 'client1',
        'status': 'pending',
        'paid': false,
        'date': Timestamp.fromDate(date),
      });
      await expectLater(
        () => service.confirmPayment('free'),
        throwsA(anything),
      );
    });
  });

  test('postponePaid libera el horario viejo y reclama el nuevo', () async {
    final oldDate = DateTime.utc(2026, 6, 1, 15);
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
      'date': Timestamp.fromDate(oldDate),
      'status': 'accepted',
      'paid': true,
      'rescheduleHistory': <Map<String, dynamic>>[],
    });
    await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-06-01T15:00')
        .set({'appointmentId': 'appt1', 'barberId': 'barber1'});

    final newDate = DateTime.utc(2026, 6, 2, 15);
    await service.postponePaid('appt1', newDate);

    final oldSlot = await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-06-01T15:00')
        .get();
    expect(oldSlot.exists, false);

    final newSlot = await firestore
        .collection('appointmentSlots')
        .doc('barber1_2026-06-02T15:00')
        .get();
    expect(newSlot.exists, true);
    expect(newSlot.data()!['appointmentId'], 'appt1');

    final updated = await firestore
        .collection('appointments')
        .doc('appt1')
        .get();
    final data = updated.data()!;
    expect(data['status'], 'postponed');
    // Timestamp.toDate() devuelve hora LOCAL, no UTC — comparar el mismo
    // instante, no la representación (que difiere según la zona horaria
    // de quien corra el test).
    expect(
      (data['date'] as Timestamp).toDate().isAtSameMomentAs(newDate),
      isTrue,
    );
    expect(data['rescheduleHistory'], hasLength(1));
  });

  test(
    'postponePaid falla sin tocar nada si el nuevo horario ya está tomado',
    () async {
      final oldDate = DateTime.utc(2026, 6, 1, 15);
      await firestore.collection('appointments').doc('appt1').set({
        'barbershopId': 'shop1',
        'barberId': 'barber1',
        'clientId': 'client1',
        'date': Timestamp.fromDate(oldDate),
        'status': 'accepted',
        'paid': true,
      });
      await firestore
          .collection('appointmentSlots')
          .doc('barber1_2026-06-01T15:00')
          .set({'appointmentId': 'appt1', 'barberId': 'barber1'});
      final newDate = DateTime.utc(2026, 6, 2, 15);
      await firestore
          .collection('appointmentSlots')
          .doc('barber1_2026-06-02T15:00')
          .set({'appointmentId': 'other', 'barberId': 'barber1'});

      await expectLater(
        () => service.postponePaid('appt1', newDate),
        throwsA(anything),
      );

      final oldSlot = await firestore
          .collection('appointmentSlots')
          .doc('barber1_2026-06-01T15:00')
          .get();
      expect(oldSlot.exists, true);
      final updated = await firestore
          .collection('appointments')
          .doc('appt1')
          .get();
      expect(updated.data()!['status'], 'accepted');
    },
  );

  test(
    'requestRefund crea la solicitud con la justificación y devuelve su id',
    () async {
      await firestore.collection('appointments').doc('appt1').set({
        'barbershopId': 'shop1',
        'clientId': 'client1',
        'paid': true,
        'status': 'accepted',
      });

      final id = await service.requestRefund(
        appointmentId: 'appt1',
        reason: 'Emergencia',
      );

      final doc = await firestore.collection('refundRequests').doc(id).get();
      final data = doc.data()!;
      expect(data['appointmentId'], 'appt1');
      expect(data['barbershopId'], 'shop1');
      expect(data['clientId'], 'client1');
      expect(data['reason'], 'Emergencia');
      expect(data['status'], 'pending');
    },
  );

  test('watchByClient entrega solo las 200 citas más recientes, en orden ascendente', () async {
    final base = DateTime.utc(2030);
    for (var i = 0; i < 205; i++) {
      await firestore.collection('appointments').doc('a$i').set({
        'barbershopId': 'shop1',
        'barberId': 'barber1',
        'barberName': 'Beto',
        'clientId': 'client1',
        'clientName': 'Ana',
        'serviceId': 'svc1',
        'serviceName': 'Corte',
        'servicePrice': 20000,
        'durationMinutes': 30,
        'date': Timestamp.fromDate(base.add(Duration(days: i))),
        'status': 'pending',
        'paid': false,
      });
    }

    final list = await service.watchByClient('client1').first;

    expect(list, hasLength(200));
    expect(list.first.id, 'a5'); // se descartan las 5 más antiguas
    expect(list.last.id, 'a204');
    expect(
      list.map((a) => a.date).toList(),
      orderedEquals([...list.map((a) => a.date)]..sort()),
    );
  });
}
