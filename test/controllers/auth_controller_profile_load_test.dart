import 'dart:async';

import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/utils/error_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockFirebaseUser extends Mock implements User {}

const _profile = AppUser(
  uid: 'u1',
  email: 'a@b.com',
  name: 'Ana',
  role: UserRole.client,
);

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockPushNotificationService push;
  late StreamController<User?> authChanges;
  late MockFirebaseUser firebaseUser;

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    push = MockPushNotificationService();
    authChanges = StreamController<User?>();
    firebaseUser = MockFirebaseUser();
    when(() => firebaseUser.uid).thenReturn('u1');
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => authChanges.stream);
    when(() => authRepository.currentUser).thenReturn(firebaseUser);
    when(() => push.onTokenRefresh)
        .thenAnswer((_) => const Stream<String>.empty());
    when(() => push.requestPermissionAndGetToken())
        .thenAnswer((_) async => null);
  });

  // Sin esperar el Future: si nadie escucha el stream, close() no termina.
  tearDown(() {
    authChanges.close();
  });

  AuthController build() => AuthController(
    authService: authRepository,
    userService: userRepository,
    pushService: push,
    profileRetryDelays: const [Duration.zero, Duration.zero],
  );

  Future<void> signInEvent() async {
    authChanges.add(firebaseUser);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('si la primera lectura del perfil falla, reintenta y entra', () async {
    var calls = 0;
    when(() => userRepository.fetchUserProfile('u1')).thenAnswer((_) async {
      calls++;
      if (calls < 3) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      }
      return _profile;
    });
    final controller = build();

    await signInEvent();

    expect(calls, 3);
    expect(controller.status, AuthStatus.authenticated);
    expect(controller.profile, _profile);
    expect(controller.profileLoadFailed, false);
  });

  test('si la lectura falla siempre, no se queda cargando: queda autenticado sin perfil y marcado como fallo', () async {
    when(() => userRepository.fetchUserProfile('u1')).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    final controller = build();

    await signInEvent();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.profile, isNull);
    expect(controller.profileLoadFailed, true);
  });

  test('retryProfile recupera el perfil cuando la red vuelve', () async {
    var online = false;
    when(() => userRepository.fetchUserProfile('u1')).thenAnswer((_) async {
      if (!online) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      }
      return _profile;
    });
    final controller = build();
    await signInEvent();
    expect(controller.profileLoadFailed, true);

    online = true;
    await controller.retryProfile();

    expect(controller.profile, _profile);
    expect(controller.profileLoadFailed, false);
    expect(controller.isBusy, false);
  });

  test('un perfil que no existe no es un fallo de carga', () async {
    when(() => userRepository.fetchUserProfile('u1'))
        .thenAnswer((_) async => null);
    final controller = build();

    await signInEvent();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.profile, isNull);
    expect(controller.profileLoadFailed, false);
  });

  group('authErrorText', () {
    FirebaseAuthException err(String code, [String? message]) =>
        FirebaseAuthException(code: code, message: message);

    test('traduce las credenciales incorrectas', () {
      for (final code in ['invalid-credential', 'user-not-found']) {
        expect(
          authErrorText(
            err(code, 'The supplied auth credential is incorrect'),
            fallback: 'x',
          ),
          'Correo o contraseña incorrectos.',
        );
      }
    });

    test('una contraseña equivocada lo dice así', () {
      expect(
        authErrorText(err('wrong-password'), fallback: 'x'),
        'Contraseña incorrecta.',
      );
    });

    test('traduce los demás códigos habituales', () {
      expect(
        authErrorText(err('too-many-requests'), fallback: 'x'),
        contains('Demasiados intentos'),
      );
      expect(
        authErrorText(err('network-request-failed'), fallback: 'x'),
        contains('Sin conexión'),
      );
      expect(
        authErrorText(err('email-already-in-use'), fallback: 'x'),
        contains('Ya existe una cuenta'),
      );
    });

    test('un código desconocido usa el mensaje o el texto de respaldo', () {
      expect(
        authErrorText(err('raro', 'Mensaje propio'), fallback: 'x'),
        'Mensaje propio',
      );
      expect(authErrorText(err('raro'), fallback: 'Respaldo'), 'Respaldo');
    });
  });
}
