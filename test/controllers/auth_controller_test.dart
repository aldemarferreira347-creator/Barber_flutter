import 'dart:async';

import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/notification_tone.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockFirebaseUser extends Mock implements User {}

const _kUid = 'user1';
const _kProfile = AppUser(
  uid: _kUid,
  email: 'a@b.com',
  name: 'Ana',
  role: UserRole.client,
);

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockPushNotificationService pushService;
  late AuthController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    pushService = MockPushNotificationService();

    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    when(() => pushService.onTokenRefresh)
        .thenAnswer((_) => const Stream<String>.empty());

    controller = AuthController(
      authService: authRepository,
      userService: userRepository,
      pushService: pushService,
    );
    controller.profile = _kProfile;
  });

  group('chooseNotificationTone', () {
    test('persiste el tono elegido y actualiza el perfil en memoria', () async {
      when(
        () => userRepository.setNotificationTone(
          _kUid,
          NotificationTone.friendly,
        ),
      ).thenAnswer((_) async {});

      final ok = await controller.chooseNotificationTone(
        NotificationTone.friendly,
      );

      expect(ok, isTrue);
      expect(controller.profile?.notificationTone, NotificationTone.friendly);
      verify(
        () => userRepository.setNotificationTone(
          _kUid,
          NotificationTone.friendly,
        ),
      ).called(1);
    });

    test(
      'no deja el perfil en un estado inconsistente si falla la escritura',
      () async {
        when(
          () => userRepository.setNotificationTone(
            _kUid,
            NotificationTone.formal,
          ),
        ).thenThrow(FirebaseException(plugin: 'firestore', message: 'offline'));

        final ok = await controller.chooseNotificationTone(
          NotificationTone.formal,
        );

        expect(ok, isFalse);
        expect(controller.profile?.notificationTone, isNull);
        expect(controller.errorMessage, 'offline');
      },
    );
  });

  group('signOut y token FCM', () {
    test('retira el token de este dispositivo del perfil ANTES de cerrar la sesión', () async {
      final authStates = StreamController<User?>();
      final user = MockFirebaseUser();
      when(() => user.uid).thenReturn(_kUid);
      when(() => authRepository.authStateChanges)
          .thenAnswer((_) => authStates.stream);
      when(() => userRepository.fetchUserProfile(_kUid))
          .thenAnswer((_) async => _kProfile);
      when(() => pushService.requestPermissionAndGetToken())
          .thenAnswer((_) async => 'tok-1');
      when(() => userRepository.addFcmToken(any(), any()))
          .thenAnswer((_) async {});
      when(() => userRepository.removeFcmToken(any(), any()))
          .thenAnswer((_) async {});
      when(() => authRepository.signOut()).thenAnswer((_) async {});

      final c = AuthController(
        authService: authRepository,
        userService: userRepository,
        pushService: pushService,
      );
      authStates.add(user);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await c.signOut();

      verifyInOrder([
        () => userRepository.removeFcmToken(_kUid, 'tok-1'),
        () => authRepository.signOut(),
      ]);
      await authStates.close();
    });

    test(
      'cierra la sesión aunque no se pueda retirar el token (sin red)',
      () async {
        final authStates = StreamController<User?>();
        final user = MockFirebaseUser();
        when(() => user.uid).thenReturn(_kUid);
        when(() => authRepository.authStateChanges)
            .thenAnswer((_) => authStates.stream);
        when(() => userRepository.fetchUserProfile(_kUid))
            .thenAnswer((_) async => _kProfile);
        when(() => pushService.requestPermissionAndGetToken())
            .thenAnswer((_) async => 'tok-1');
        when(() => userRepository.addFcmToken(any(), any()))
            .thenAnswer((_) async {});
        when(
          () => userRepository.removeFcmToken(any(), any()),
        ).thenThrow(FirebaseException(plugin: 'firestore', message: 'offline'));
        when(() => authRepository.signOut()).thenAnswer((_) async {});

        final c = AuthController(
          authService: authRepository,
          userService: userRepository,
          pushService: pushService,
        );
        authStates.add(user);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await c.signOut();

        verify(() => authRepository.signOut()).called(1);
        await authStates.close();
      },
    );
  });
}
