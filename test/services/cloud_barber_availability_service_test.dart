import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/services/cloud_barber_availability_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  late MockFirebaseFunctions functions;
  late CloudBarberAvailabilityService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    service = CloudBarberAvailabilityService(functions: functions);
  });

  test('markAway envía estimatedMinutes', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('markBarberAway')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.markAway(30);

    verify(() => callable.call<void>({'estimatedMinutes': 30})).called(1);
  });

  test('markReturned llama a la función sin argumentos', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('markBarberReturned')).thenReturn(callable);
    when(() => callable.call<void>()).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.markReturned();

    verify(() => callable.call<void>()).called(1);
  });
}
