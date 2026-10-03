import 'dart:typed_data';

import 'package:barber/models/barbershop.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/storage_repository.dart';
import 'package:barber/services/firestore_barbershop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageRepository extends Mock implements StorageRepository {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockStorageRepository storage;
  late MockUser user;
  late FirestoreBarbershopService service;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    storage = MockStorageRepository();
    user = MockUser();
    final auth = MockFirebaseAuth();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('admin1');
    service = FirestoreBarbershopService(
      storage: storage,
      firestore: firestore,
      auth: auth,
    );
  });

  DocumentReference<Map<String, dynamic>> shop(String id) =>
      firestore.collection('barbershops').doc(id);

  Future<Map<String, dynamic>> read(
    DocumentReference<Map<String, dynamic>> r,
  ) async => (await r.get()).data()!;

  double daysAhead(Timestamp due) =>
      due.toDate().difference(DateTime.now()).inHours / 24;

  test('uploadPhoto sube la foto y guarda su URL en el documento', () async {
    await shop('shop1').set({'name': 'BarberFlow', 'ownerId': 'owner1'});
    when(
      () => storage.uploadBytes(
        path: any(named: 'path'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async => 'https://example.com/shop.png');

    final bytes = Uint8List.fromList([1, 2, 3]);
    await service.uploadPhoto('shop1', fileName: 'cover.png', bytes: bytes);

    verify(
      () => storage.uploadBytes(
        path: 'barbershops/shop1/profile/cover.png',
        bytes: bytes,
      ),
    ).called(1);
    expect(
      (await read(shop('shop1')))['photoUrl'],
      'https://example.com/shop.png',
    );
  });

  group('watchApproved (catálogo del cliente)', () {
    Future<void> seed(String id, Map<String, dynamic> fields) => shop(id).set({
      'name': id,
      'ownerId': 'owner1',
      'active': true,
      'approvalStatus': 'approved',
      ...fields,
    });

    test('solo trae barberías aprobadas y activas', () async {
      await seed('ok', {});
      await seed('pendiente', {'approvalStatus': 'pending'});
      await seed('inactiva', {'active': false});

      final shops = await service.watchApproved().first;

      expect(shops.map((s) => s.id), ['ok']);
    });

    test('oculta las que pasaron su mensualidad más allá de la gracia (4 días por defecto)', () async {
      final now = DateTime.now();
      await seed('vigente', {
        'paymentDueDate': Timestamp.fromDate(now.add(const Duration(days: 10))),
      });
      await seed('en-gracia', {
        'paymentDueDate': Timestamp.fromDate(
          now.subtract(const Duration(days: 2)),
        ),
      });
      await seed('vencida', {
        'paymentDueDate': Timestamp.fromDate(
          now.subtract(const Duration(days: 6)),
        ),
      });

      final shops = await service.watchApproved().first;

      expect(shops.map((s) => s.id).toSet(), {'vigente', 'en-gracia'});
    });

    test('respeta los días de gracia que configuró el admin', () async {
      await seed('vencida', {
        'paymentDueDate': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 6)),
        ),
      });
      await firestore.collection('platformSettings').doc('main').set({
        'nequiPhone': '3001234567',
        'monthlyFee': 50000,
        'graceDays': 10,
      });

      final shops = await service.watchApproved().first;

      expect(shops.map((s) => s.id), ['vencida']);
    });
  });

  group('mensualidad por Nequi', () {
    Future<void> seedApproved({DateTime? due, String status = 'ok'}) =>
        shop('shop1').set({
          'name': 'BarberFlow',
          'ownerId': 'owner1',
          'approvalStatus': 'approved',
          'active': status == 'ok',
          'paymentStatus': status,
          'paymentDueDate': due == null ? null : Timestamp.fromDate(due),
        });

    test(
      'paySubscription solo registra el pago pendiente: la barbería NO cambia',
      () async {
        await seedApproved(status: 'overdue');
        final before = await read(shop('shop1'));

        await service.paySubscription('shop1', reference: 'M1234567');

        final payments = await firestore.collection('payments').get();
        expect(payments.docs, hasLength(1));
        final payment = payments.docs.single.data();
        expect(payment['payerId'], 'owner1');
        expect(payment['category'], 'subscription');
        expect(payment['relatedId'], 'shop1');
        expect(payment['status'], 'pending');
        expect(payment['reference'], 'M1234567');
        expect(payment['method'], 'nequi');
        expect(payment['amount'], kBarbershopMonthlyFee);
        expect(await read(shop('shop1')), before);
      },
    );

    test(
      'el valor del pago es la mensualidad configurada por el admin',
      () async {
        await seedApproved();
        await firestore.collection('platformSettings').doc('main').set({
          'nequiPhone': '3001234567',
          'monthlyFee': 80000,
          'graceDays': 4,
        });

        await service.paySubscription('shop1', reference: 'M1234567');

        final payment =
            (await firestore.collection('payments').get()).docs.single;
        expect(payment.data()['amount'], 80000);
      },
    );

    test('confirmSubscriptionPayment aprueba el pago y renueva 30 días (barbería vencida: desde hoy)', () async {
      await seedApproved(
        due: DateTime.now().subtract(const Duration(days: 8)),
        status: 'blocked',
      );
      await service.paySubscription('shop1', reference: 'M1234567');
      final paymentId =
          (await firestore.collection('payments').get()).docs.single.id;

      await service.confirmSubscriptionPayment(paymentId);

      final payment = await read(
        firestore.collection('payments').doc(paymentId),
      );
      expect(payment['status'], 'approved');
      expect(payment['resolvedBy'], 'admin1');
      final updated = await read(shop('shop1'));
      expect(updated['paymentStatus'], 'ok');
      expect(updated['active'], true);
      expect(
        daysAhead(updated['paymentDueDate'] as Timestamp),
        inInclusiveRange(29, 30.1),
      );
    });

    test(
      'pagar antes del vencimiento suma 30 días al vencimiento actual',
      () async {
        await seedApproved(due: DateTime.now().add(const Duration(days: 10)));
        await service.paySubscription('shop1', reference: 'M1234567');
        final paymentId =
            (await firestore.collection('payments').get()).docs.single.id;

        await service.confirmSubscriptionPayment(paymentId);

        final updated = await read(shop('shop1'));
        expect(
          daysAhead(updated['paymentDueDate'] as Timestamp),
          inInclusiveRange(39, 40.1),
        );
      },
    );

    test('un pago ya resuelto no se puede confirmar de nuevo', () async {
      await seedApproved();
      await service.paySubscription('shop1', reference: 'M1234567');
      final paymentId =
          (await firestore.collection('payments').get()).docs.single.id;
      await service.confirmSubscriptionPayment(paymentId);

      await expectLater(
        () => service.confirmSubscriptionPayment(paymentId),
        throwsA(anything),
      );
    });

    test('rejectSubscriptionPayment rechaza el pago y deja la barbería como estaba', () async {
      await seedApproved(status: 'overdue');
      await service.paySubscription('shop1', reference: 'M1234567');
      final paymentId =
          (await firestore.collection('payments').get()).docs.single.id;
      final before = await read(shop('shop1'));

      await service.rejectSubscriptionPayment(paymentId);

      expect(
        (await read(firestore.collection('payments').doc(paymentId)))['status'],
        'rejected',
      );
      expect(await read(shop('shop1')), before);
    });

    test('cancelSubscription bloquea la barbería de inmediato, sin período de gracia', () async {
      await seedApproved();

      await service.cancelSubscription('shop1');

      final updated = await read(shop('shop1'));
      expect(updated['paymentStatus'], 'blocked');
      expect(updated['active'], false);
    });
  });

  group('resolveApproval', () {
    Future<String> seedPendingWithPayment() async {
      final payment = await firestore.collection('payments').add({
        'payerId': 'owner1',
        'category': 'subscription',
        'relatedId': 'shop1',
        'amount': 50000,
        'status': 'pending',
        'reference': 'M1234567',
      });
      await shop('shop1').set({
        'name': 'BarberFlow',
        'ownerId': 'owner1',
        'approvalStatus': 'pending',
        'active': false,
        'paymentId': payment.id,
      });
      return payment.id;
    }

    test(
      'rechazar marca la barbería rechazada y su pago como no recibido',
      () async {
        final paymentId = await seedPendingWithPayment();

        await service.resolveApproval('shop1', approve: false);

        expect((await read(shop('shop1')))['approvalStatus'], 'rejected');
        final payment = await read(
          firestore.collection('payments').doc(paymentId),
        );
        expect(payment['status'], 'rejected');
        expect(payment['resolvedBy'], 'admin1');
      },
    );

    test(
      'aprobar confirma el pago, activa la barbería y arranca el primer ciclo',
      () async {
        final paymentId = await seedPendingWithPayment();

        await service.resolveApproval('shop1', approve: true);

        final updated = await read(shop('shop1'));
        expect(updated['approvalStatus'], 'approved');
        expect(updated['active'], true);
        expect(updated['paymentStatus'], 'ok');
        expect(
          daysAhead(updated['paymentDueDate'] as Timestamp),
          inInclusiveRange(29, 30.1),
        );
        expect(
          (await read(
            firestore.collection('payments').doc(paymentId),
          ))['status'],
          'approved',
        );
      },
    );

    test('aprobar una barbería sin pago registrado también funciona', () async {
      await shop('shop1').set({
        'name': 'BarberFlow',
        'ownerId': 'owner1',
        'approvalStatus': 'pending',
        'active': false,
      });

      await service.resolveApproval('shop1', approve: true);

      expect((await read(shop('shop1')))['approvalStatus'], 'approved');
    });
  });

  test(
    'updateInfo guarda el Nequi normalizado, o lo borra si queda vacío',
    () async {
      await shop('shop1')
          .set({'name': 'A', 'ownerId': 'owner1', 'nequiPhone': '3001112233'});

      await service.updateInfo(
        'shop1',
        name: 'B',
        address: 'Calle 1',
        nequiPhone: '+57 300 123 4567',
      );
      expect((await read(shop('shop1')))['nequiPhone'], '3001234567');

      await service.updateInfo(
        'shop1',
        name: 'B',
        address: 'Calle 1',
        nequiPhone: '  ',
      );
      expect((await read(shop('shop1')))['nequiPhone'], isNull);
    },
  );

  group('borradores (máximo $kMaxBarbershopDrafts, cupos {uid}_1..5)', () {
    const draft = Barbershop(id: '', name: 'Borrador', ownerId: 'owner1');

    CollectionReference<Map<String, dynamic>> drafts() =>
        firestore.collection('barbershopDrafts');

    test('saveDraft usa el primer cupo libre', () async {
      await drafts().doc('owner1_1').set({'ownerId': 'owner1', 'name': 'Otro'});

      final id = await service.saveDraft(draft);

      expect(id, 'owner1_2');
      final data = await read(drafts().doc('owner1_2'));
      expect(data['ownerId'], 'owner1');
      expect(data['name'], 'Borrador');
      // Un borrador no lleva estados de aprobación ni de pago.
      expect(data.containsKey('approvalStatus'), false);
      expect(data.containsKey('paymentStatus'), false);
      expect(data.containsKey('active'), false);
    });

    test(
      'saveDraft lanza BarbershopDraftLimitException con los 5 cupos ocupados',
      () async {
        for (var n = 1; n <= kMaxBarbershopDrafts; n++) {
          await drafts().doc('owner1_$n').set({'ownerId': 'owner1'});
        }

        await expectLater(
          () => service.saveDraft(draft),
          throwsA(isA<BarbershopDraftLimitException>()),
        );
      },
    );

    test('publishDraft registra el pago pendiente, crea la barbería pendiente y borra el borrador', () async {
      await drafts().doc('owner1_1').set({
        'name': 'Mi barbería',
        'ownerId': 'owner1',
        'address': 'Calle 1',
      });

      final id = await service.publishDraft('owner1_1', reference: 'M1234567');

      final payment =
          (await firestore.collection('payments').get()).docs.single;
      expect(payment.data()['payerId'], 'owner1');
      expect(payment.data()['category'], 'subscription');
      expect(payment.data()['relatedId'], id);
      expect(payment.data()['amount'], kBarbershopMonthlyFee);
      expect(payment.data()['status'], 'pending');
      expect(payment.data()['reference'], 'M1234567');

      final created = await read(shop(id));
      expect(created['approvalStatus'], 'pending');
      expect(created['active'], false);
      expect(created['paymentId'], payment.id);
      expect(created['ownerId'], 'owner1');
      expect((await drafts().doc('owner1_1').get()).exists, false);
    });

    test('createPaid no toca ningún borrador', () async {
      await drafts().doc('owner1_1').set({'ownerId': 'owner1', 'name': 'Otro'});

      final id = await service.createPaid(draft, reference: 'M1234567');

      expect((await shop(id).get()).exists, true);
      expect((await drafts().doc('owner1_1').get()).exists, true);
    });
  });
}
