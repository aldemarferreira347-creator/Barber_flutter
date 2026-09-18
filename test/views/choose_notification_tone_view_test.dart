import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/notification_tone.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/notification/choose_notification_tone_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock implements PushNotificationService {}

const _kUid = 'user1';

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
    controller.profile = AppUser(uid: _kUid, email: 'a@b.com', name: 'Ana', role: UserRole.client);
  });

  Widget wrap() {
    return ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: const MaterialApp(home: ChooseNotificationToneView()),
    );
  }

  testWidgets('el botón Continuar está deshabilitado hasta elegir un tono', (tester) async {
    await tester.pumpWidget(wrap());

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('elegir un tono y confirmar lo guarda en el controlador', (tester) async {
    when(() => userRepository.setNotificationTone(_kUid, NotificationTone.informal)).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());

    await tester.tap(find.text(NotificationTone.informal.label));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(() => userRepository.setNotificationTone(_kUid, NotificationTone.informal)).called(1);
    expect(controller.profile?.notificationTone, NotificationTone.informal);
  });
}
