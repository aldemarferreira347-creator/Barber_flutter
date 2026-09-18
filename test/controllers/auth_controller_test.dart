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

class MockPushNotificationService extends Mock implements PushNotificationService {}

const _kUid = 'user1';
final _kProfile = AppUser(uid: _kUid, email: 'a@b.com', name: 'Ana', role: UserRole.client);

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockPushNotificationService pushService;
  late AuthController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    pushService = MockPushNotificationService();

    when(() => authRepository.authStateChanges).thenAnswer((_) => const Stream<User?>.empty());
    when(() => pushService.onTokenRefresh).thenAnswer((_) => const Stream<String>.empty());

    controller = AuthController(authService: authRepository, userService: userRepository, pushService: pushService);
    controller.profile = _kProfile;
  });

  group('chooseNotificationTone', () {
    test('persiste el tono elegido y actualiza el perfil en memoria', () async {
      when(() => userRepository.setNotificationTone(_kUid, NotificationTone.friendly)).thenAnswer((_) async {});

      final ok = await controller.chooseNotificationTone(NotificationTone.friendly);

      expect(ok, isTrue);
      expect(controller.profile?.notificationTone, NotificationTone.friendly);
      verify(() => userRepository.setNotificationTone(_kUid, NotificationTone.friendly)).called(1);
    });

    test('no deja el perfil en un estado inconsistente si falla la escritura', () async {
      when(() => userRepository.setNotificationTone(_kUid, NotificationTone.formal))
          .thenThrow(FirebaseException(plugin: 'firestore', message: 'offline'));

      final ok = await controller.chooseNotificationTone(NotificationTone.formal);

      expect(ok, isFalse);
      expect(controller.profile?.notificationTone, isNull);
      expect(controller.errorMessage, 'offline');
    });
  });
}
