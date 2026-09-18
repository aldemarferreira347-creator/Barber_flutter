import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/services/cloud_shop_closure_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  late MockFirebaseFunctions functions;
  late CloudShopClosureService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    service = CloudShopClosureService(functions: functions);
  });

  test('closeForExternalEvent envía el payload esperado y devuelve appointmentsAffected', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    final from = DateTime(2026, 1, 10, 8, 0);
    final until = DateTime(2026, 1, 10, 12, 0);

    when(() => functions.httpsCallable('closeShopForExternalEvent')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'closureId': 'closure1', 'appointmentsAffected': 3});

    final affected = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Corte de energía',
    );

    expect(affected, 3);
    verify(
      () => callable.call<Map<String, dynamic>>({
        'barbershopId': 'shop1',
        'closedFrom': from.toIso8601String(),
        'closedUntil': until.toIso8601String(),
        'reason': 'Corte de energía',
      }),
    ).called(1);
  });

  test('closeForExternalEvent devuelve 0 cuando no hubo reservas afectadas', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    final from = DateTime(2026, 1, 10, 8, 0);
    final until = DateTime(2026, 1, 10, 12, 0);

    when(() => functions.httpsCallable('closeShopForExternalEvent')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'closureId': 'closure2', 'appointmentsAffected': 0});

    final affected = await service.closeForExternalEvent(
      barbershopId: 'shop1',
      closedFrom: from,
      closedUntil: until,
      reason: 'Emergencia',
    );

    expect(affected, 0);
  });
}
