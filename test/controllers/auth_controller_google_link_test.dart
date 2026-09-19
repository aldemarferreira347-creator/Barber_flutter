import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock implements PushNotificationService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeAuthCredential extends Fake implements AuthCredential {}

const _kUid = 'user1';
const _kEmail = 'existing@example.com';

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late AuthController controller;
  late FakeAuthCredential pendingCredential;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(const AppUser(uid: 'fallback', email: '', name: '', role: UserRole.client));
  });

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    final pushService = MockPushNotificationService();
    pendingCredential = FakeAuthCredential();

    when(() => authRepository.authStateChanges).thenAnswer((_) => const Stream<User?>.empty());
    when(() => pushService.onTokenRefresh).thenAnswer((_) => const Stream<String>.empty());

    controller = AuthController(authService: authRepository, userService: userRepository, pushService: pushService);
  });

  test('login exitoso con Google carga/crea el perfil Cliente', () async {
    final user = MockUser();
    when(() => user.uid).thenReturn(_kUid);
    when(() => user.email).thenReturn(_kEmail);
    when(() => user.displayName).thenReturn('Ana');
    when(() => user.phoneNumber).thenReturn(null);
    final credential = MockUserCredential();
    when(() => credential.user).thenReturn(user);

    when(() => authRepository.signInWithGoogle()).thenAnswer((_) async => GoogleSignInSuccess(credential));
    when(() => userRepository.fetchUserProfile(_kUid)).thenAnswer((_) async => null);
    when(() => userRepository.createUserProfile(any())).thenAnswer((_) async {});

    final outcome = await controller.signInWithGoogle();

    expect(outcome, isA<GoogleSignInSuccess>());
    expect(controller.profile?.uid, _kUid);
    verify(() => userRepository.createUserProfile(any())).called(1);
  });

  test('cuando el correo ya tiene cuenta con contraseña, no toca el perfil y devuelve el pedido de vínculo', () async {
    when(() => authRepository.signInWithGoogle()).thenAnswer(
      (_) async => GoogleSignInRequiresPasswordLink(email: _kEmail, pendingGoogleCredential: pendingCredential),
    );

    final outcome = await controller.signInWithGoogle();

    expect(outcome, isA<GoogleSignInRequiresPasswordLink>());
    expect((outcome as GoogleSignInRequiresPasswordLink).email, _kEmail);
    expect(controller.profile, isNull);
    verifyNever(() => userRepository.fetchUserProfile(any()));
  });

  test('cancelar el selector de Google no es un error', () async {
    when(() => authRepository.signInWithGoogle()).thenAnswer((_) async => const GoogleSignInCancelled());

    final outcome = await controller.signInWithGoogle();

    expect(outcome, isA<GoogleSignInCancelled>());
    expect(controller.errorMessage, isNull);
  });

  group('confirmGoogleLinkWithPassword', () {
    test('vincula ambos métodos y completa el login', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn(_kUid);
      when(() => user.email).thenReturn(_kEmail);
      when(() => user.displayName).thenReturn('Ana');
      when(() => user.phoneNumber).thenReturn(null);
      final credential = MockUserCredential();
      when(() => credential.user).thenReturn(user);

      when(
        () => authRepository.linkGoogleWithPassword(
          email: _kEmail,
          password: 'secret123',
          pendingGoogleCredential: pendingCredential,
        ),
      ).thenAnswer((_) async => credential);
      when(() => userRepository.fetchUserProfile(_kUid))
          .thenAnswer((_) async => AppUser(uid: _kUid, email: _kEmail, name: 'Ana', role: UserRole.client));

      final ok = await controller.confirmGoogleLinkWithPassword(
        email: _kEmail,
        password: 'secret123',
        pendingGoogleCredential: pendingCredential,
      );

      expect(ok, isTrue);
      expect(controller.profile?.uid, _kUid);
    });

    test('contraseña incorrecta no deja al usuario autenticado', () async {
      when(
        () => authRepository.linkGoogleWithPassword(
          email: _kEmail,
          password: 'wrong',
          pendingGoogleCredential: pendingCredential,
        ),
      ).thenThrow(FirebaseAuthException(code: 'wrong-password', message: 'Contraseña incorrecta'));

      final ok = await controller.confirmGoogleLinkWithPassword(
        email: _kEmail,
        password: 'wrong',
        pendingGoogleCredential: pendingCredential,
      );

      expect(ok, isFalse);
      expect(controller.profile, isNull);
      expect(controller.errorMessage, 'Contraseña incorrecta');
    });
  });
}
