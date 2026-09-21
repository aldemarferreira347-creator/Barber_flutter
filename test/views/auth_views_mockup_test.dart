import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/auth/login_view.dart';
import 'package:barber/views/auth/register_view.dart';
import 'package:barber/views/splash/splash_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

void main() {
  late MockAuthRepository authRepository;
  late MockUserRepository userRepository;
  late MockPushNotificationService pushService;
  late AuthController controller;

  setUp(() {
    authRepository = MockAuthRepository();
    userRepository = MockUserRepository();
    pushService = MockPushNotificationService();

    when(
      () => authRepository.authStateChanges,
    ).thenAnswer((_) => const Stream<User?>.empty());
    when(
      () => pushService.onTokenRefresh,
    ).thenAnswer((_) => const Stream<String>.empty());

    controller = AuthController(
      authService: authRepository,
      userService: userRepository,
      pushService: pushService,
    );
  });

  Widget wrapWithAuth(Widget child) {
    return ChangeNotifierProvider<AuthController>.value(
      value: controller,
      child: MaterialApp(home: child),
    );
  }

  testWidgets('SplashView muestra imagen de fondo, marca y lemas', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithAuth(const SplashView()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BarberFlow'), findsOneWidget);
    expect(find.text('Tu barbería, siempre conectada'), findsOneWidget);
    expect(find.text('Gestiona   •   Organiza   •   Crece'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    // Drenar el timer del splash para que no quede pendiente
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'LoginView muestra marca, formulario, fondo y botón de Google',
    (tester) async {
      await tester.pumpWidget(wrapWithAuth(const LoginView()));
      await tester.pumpAndSettle();

      expect(find.text('BarberFlow'), findsOneWidget);
      expect(find.text('Tu barbería, siempre conectada'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(find.text('Accede a tu cuenta para continuar'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('¿No tienes una cuenta? '), findsOneWidget);
      expect(find.text('Regístrate'), findsOneWidget);
    },
  );

  testWidgets('RegisterView muestra campos de registro y botón crear cuenta', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithAuth(const RegisterView()));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(
      find.text('Completa la información para registrarte'),
      findsOneWidget,
    );
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Confirmar contraseña'), findsOneWidget);

    expect(find.text('Registrarse'), findsOneWidget);
    expect(find.text('¿Ya tienes una cuenta? '), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
