import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/appointment.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/rating_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/appointment/client_appointments_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock implements PushNotificationService {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

const _kUid = 'client1';

Appointment _appointment(String id, AppointmentStatus status, DateTime date, {bool paid = false}) {
  return Appointment(
    id: id,
    barbershopId: 'shop1',
    barberId: 'barber1',
    barberName: 'Beto',
    clientId: _kUid,
    clientName: 'Ana',
    serviceId: 'svc1',
    serviceName: 'Corte',
    servicePrice: 20000,
    durationMinutes: 30,
    date: date,
    status: status,
    paid: paid,
    paymentId: paid ? 'payment1' : null,
  );
}

void main() {
  late AuthController authController;
  late MockAppointmentRepository appointmentRepository;
  late MockRatingRepository ratingRepository;

  setUp(() {
    final authRepository = MockAuthRepository();
    final userRepository = MockUserRepository();
    final pushService = MockPushNotificationService();
    when(() => authRepository.authStateChanges).thenAnswer((_) => const Stream<User?>.empty());
    when(() => pushService.onTokenRefresh).thenAnswer((_) => const Stream<String>.empty());

    authController = AuthController(authService: authRepository, userService: userRepository, pushService: pushService);
    authController.profile = AppUser(uid: _kUid, email: 'a@b.com', name: 'Ana', role: UserRole.client);

    appointmentRepository = MockAppointmentRepository();
    ratingRepository = MockRatingRepository();
    when(() => ratingRepository.watchRatedAppointmentIds(_kUid)).thenAnswer((_) => Stream.value(const {}));
  });

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        Provider<AppointmentRepository>.value(value: appointmentRepository),
        Provider<RatingRepository>.value(value: ratingRepository),
      ],
      child: const MaterialApp(home: ClientAppointmentsView()),
    );
  }

  testWidgets('muestra el estado vacío cuando no hay ninguna cita', (tester) async {
    when(() => appointmentRepository.watchByClient(_kUid)).thenAnswer((_) => Stream.value(const []));

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('No tienes citas programadas'), findsOneWidget);
  });

  testWidgets('agrupa próximas (pending/accepted) e historial (el resto) por separado', (tester) async {
    final now = DateTime(2026, 1, 1);
    when(() => appointmentRepository.watchByClient(_kUid)).thenAnswer(
      (_) => Stream.value([
        _appointment('a1', AppointmentStatus.pending, now),
        _appointment('a2', AppointmentStatus.completed, now.subtract(const Duration(days: 1))),
        _appointment('a3', AppointmentStatus.cancelled, now.subtract(const Duration(days: 2))),
      ]),
    );

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // contador de "Próximas"
    expect(find.text('2'), findsOneWidget); // contador de "Historial"
    // Solo la cita próxima (pending) ofrece cancelar.
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('cancelar una cita pagada ofrece posponer en vez de cancelar directo (spec 6.3)', (tester) async {
    final now = DateTime(2026, 1, 1);
    when(() => appointmentRepository.watchByClient(_kUid))
        .thenAnswer((_) => Stream.value([_appointment('a1', AppointmentStatus.pending, now, paid: true)]));

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Esta cita ya está pagada'), findsOneWidget);
    expect(find.text('Posponer'), findsOneWidget);
    expect(find.text('Cancelar de todas formas'), findsOneWidget);
    // No debe mostrarse el diálogo simple de cancelación directa.
    expect(find.text('¿Cancelar tu cita de Corte?'), findsNothing);
  });

  testWidgets('insistir en cancelar una cita pagada pide una justificación y llama a requestRefund', (tester) async {
    final now = DateTime(2026, 1, 1);
    when(() => appointmentRepository.watchByClient(_kUid))
        .thenAnswer((_) => Stream.value([_appointment('a1', AppointmentStatus.pending, now, paid: true)]));
    when(() => appointmentRepository.requestRefund(appointmentId: 'a1', reason: 'Emergencia médica'))
        .thenAnswer((_) async => 'req1');

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar de todas formas'));
    await tester.pumpAndSettle();

    expect(find.text('Justifica la cancelación'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Emergencia médica');
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    verify(() => appointmentRepository.requestRefund(appointmentId: 'a1', reason: 'Emergencia médica')).called(1);
  });
}
