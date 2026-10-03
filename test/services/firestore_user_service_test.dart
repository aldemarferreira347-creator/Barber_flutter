import 'package:barber/models/user_role.dart';
import 'package:barber/services/firestore_user_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreUserService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = FirestoreUserService(firestore: firestore);
    await firestore.collection('users').doc('u1').set({
      'email': 'viejo@barber.test',
      'name': 'Viejo Nombre',
      'role': 'client',
      'active': true,
    });
  });

  Future<Map<String, dynamic>?> read() async =>
      (await firestore.collection('users').doc('u1').get()).data();

  group('updateProfile', () {
    test('aplica nombre, correo y rol juntos y normaliza', () async {
      await service.updateProfile(
        'u1',
        name: '  Nuevo Nombre ',
        email: ' Nuevo@Barber.Test ',
        role: UserRole.barber,
      );

      final data = await read();
      expect(data?['name'], 'Nuevo Nombre');
      expect(data?['email'], 'nuevo@barber.test');
      expect(data?['role'], 'barber');
      expect(data?['active'], true, reason: 'no toca lo que no se pidió');
    });

    test('solo escribe lo que se pasa', () async {
      await service.updateProfile('u1', role: UserRole.owner);

      final data = await read();
      expect(data?['role'], 'owner');
      expect(data?['name'], 'Viejo Nombre');
      expect(data?['email'], 'viejo@barber.test');
    });

    test(
      'sin cambios no escribe nada (ni siquiera a un perfil ajeno)',
      () async {
        await service.updateProfile('no-existe');
        expect(
          (await firestore.collection('users').doc('no-existe').get()).exists,
          isFalse,
        );
      },
    );
  });

  group('consultas compartidas', () {
    test('dos oyentes de watchAll comparten el mismo Stream', () async {
      expect(identical(service.watchAll(), service.watchAll()), isTrue);
    });

    test('un cambio llega a los oyentes ya suscritos', () async {
      final seen = <List<String>>[];
      final sub = service.watchAll().listen(
        (users) => seen.add([for (final u in users) u.name]),
      );
      await Future<void>.delayed(Duration.zero);

      await firestore.collection('users').doc('u2').set({
        'email': 'otro@barber.test',
        'name': 'Zeta',
        'role': 'client',
        'active': true,
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, containsAll(['Viejo Nombre', 'Zeta']));
      await sub.cancel();
    });
  });
}
