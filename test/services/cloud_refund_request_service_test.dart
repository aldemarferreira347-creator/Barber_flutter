import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/models/refund_request.dart';
import 'package:barber/services/cloud_refund_request_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

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
  late CloudRefundRequestService service;

  setUp(() {
    functions = MockFirebaseFunctions();
    firestore = MockFirebaseFirestore();
    service = CloudRefundRequestService(functions: functions, firestore: firestore);
  });

  test('resolve(approve: true) llama a la función con approve true', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('resolveAppointmentRefund')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.resolve('req1', approve: true);

    verify(() => callable.call<void>({'requestId': 'req1', 'approve': true})).called(1);
  });

  test('resolve(approve: false) llama a la función con approve false', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('resolveAppointmentRefund')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await service.resolve('req1', approve: false);

    verify(() => callable.call<void>({'requestId': 'req1', 'approve': false})).called(1);
  });

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
