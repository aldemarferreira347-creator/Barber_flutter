import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/services/firestore_appointment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  late MockFirebaseFunctions functions;
  late FirestoreAppointmentService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    service = FirestoreAppointmentService(functions: functions, firestore: MockFirebaseFirestore());
  });

  test('createPaid envía los datos de la reserva y devuelve el id', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('bookPaidAppointment')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'id': 'appt1'});

    final date = DateTime(2026, 6, 1, 15, 0);
    final id = await service.createPaid(
      barbershopId: 'shop1',
      barberId: 'barber1',
      barberName: 'Beto',
      serviceId: 'svc1',
      clientName: 'Ana',
      date: date,
    );

    expect(id, 'appt1');
    verify(() => callable.call<Map<String, dynamic>>({
          'barbershopId': 'shop1',
          'barberId': 'barber1',
          'barberName': 'Beto',
          'serviceId': 'svc1',
          'clientName': 'Ana',
          'date': date.toIso8601String(),
        })).called(1);
  });

  test('postponePaid envía appointmentId y newDate', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('postponeAppointment')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    final newDate = DateTime(2026, 6, 2, 15, 0);
    await service.postponePaid('appt1', newDate);

    verify(() => callable.call<void>({'appointmentId': 'appt1', 'newDate': newDate.toIso8601String()})).called(1);
  });

  test('requestRefund envía la justificación y devuelve el id de la solicitud', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('requestAppointmentRefund')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'id': 'req1'});

    final id = await service.requestRefund(appointmentId: 'appt1', reason: 'Emergencia');

    expect(id, 'req1');
    verify(() => callable.call<Map<String, dynamic>>({
          'appointmentId': 'appt1',
          'reason': 'Emergencia',
          'purchaseId': null,
          'purchaseItemIndexes': null,
        })).called(1);
  });
}
