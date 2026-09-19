import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barber/models/payment_record.dart';
import 'package:barber/services/nequi_payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFunctions functions;
  late MockFirebaseFirestore firestore;
  late NequiPaymentGateway gateway;

  setUp(() {
    functions = MockFirebaseFunctions();
    firestore = MockFirebaseFirestore();
    gateway = NequiPaymentGateway(functions: functions, firestore: firestore);
  });

  test('requestPayment envía el payload esperado y devuelve el id creado', () async {
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('requestPayment')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'id': 'payment1'});

    final id = await gateway.requestPayment(amount: 20000, category: PaymentCategory.appointment, relatedId: 'appt1');

    expect(id, 'payment1');
    verify(
      () => callable.call<Map<String, dynamic>>({
        'amount': 20000.0,
        'category': 'appointment',
        'relatedId': 'appt1',
        'description': null,
      }),
    ).called(1);
  });

  test('refund envía el monto solo cuando se especifica', () async {
    final callable = MockHttpsCallable();
    when(() => functions.httpsCallable('refundPayment')).thenReturn(callable);
    when(() => callable.call<void>(any())).thenAnswer((_) async => MockHttpsCallableResult<void>());

    await gateway.refund('payment1');
    verify(() => callable.call<void>({'paymentId': 'payment1'})).called(1);

    await gateway.refund('payment1', amount: 5000);
    verify(() => callable.call<void>({'paymentId': 'payment1', 'amount': 5000.0})).called(1);
  });

  test('watchPayment traduce el snapshot de Firestore a PaymentRecord', () async {
    final collection = MockCollectionReference();
    final docRef = MockDocumentReference();
    final snapshot = MockDocumentSnapshot();

    when(() => firestore.collection('payments')).thenReturn(collection);
    when(() => collection.doc('payment1')).thenReturn(docRef);
    when(() => docRef.snapshots()).thenAnswer((_) => Stream.value(snapshot));
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.id).thenReturn('payment1');
    when(() => snapshot.data()).thenReturn({
      'payerId': 'user1',
      'amount': 20000.0,
      'category': 'appointment',
      'relatedId': 'appt1',
      'status': 'approved',
    });

    final record = await gateway.watchPayment('payment1').first;

    expect(record, isNotNull);
    expect(record!.status, PaymentIntentStatus.approved);
    expect(record.amount, 20000.0);
  });

  test('watchPayment devuelve null si el pago no existe', () async {
    final collection = MockCollectionReference();
    final docRef = MockDocumentReference();
    final snapshot = MockDocumentSnapshot();

    when(() => firestore.collection('payments')).thenReturn(collection);
    when(() => collection.doc('ghost')).thenReturn(docRef);
    when(() => docRef.snapshots()).thenAnswer((_) => Stream.value(snapshot));
    when(() => snapshot.exists).thenReturn(false);
    when(() => snapshot.data()).thenReturn(null);

    final record = await gateway.watchPayment('ghost').first;

    expect(record, isNull);
  });
}
