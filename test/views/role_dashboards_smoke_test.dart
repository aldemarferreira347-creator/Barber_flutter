import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/appointment.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/notification_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/home/admin_dashboard_tab.dart';
import 'package:barber/views/home/barber_dashboard_tab.dart';
import 'package:barber/views/home/client_dashboard_tab.dart';
import 'package:barber/views/home/owner_dashboard_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Prueba de humo (smoke test) de los 4 dashboards de rol rediseñados: monta
// cada uno con dependencias mockeadas y verifica que construyen su árbol de
// widgets sin lanzar excepciones (RenderFlex overflow, nulls, etc.) — algo
// que `flutter analyze` no puede detectar porque son errores en tiempo de
// ejecución, no de compilación.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

const _uid = 'user1';

void main() {
  late AuthController authController;
  late MockBarbershopRepository barbershopRepository;
  late MockUserRepository userRepository;
  late MockNotificationRepository notificationRepository;
  late MockAppointmentRepository appointmentRepository;

  setUp(() {
    final authRepository = MockAuthRepository();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    authController = AuthController(
      authService: authRepository,
      userService: MockUserRepository(),
      pushService: MockPushNotificationService(),
    );
    barbershopRepository = MockBarbershopRepository();
    userRepository = MockUserRepository();
    notificationRepository = MockNotificationRepository();
    appointmentRepository = MockAppointmentRepository();

    when(() => barbershopRepository.watchAll())
        .thenAnswer((_) => Stream.value(const []));
    when(() => barbershopRepository.watchByOwner(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => barbershopRepository.watchOne(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => userRepository.watchAll())
        .thenAnswer((_) => Stream.value(const []));
    when(() => appointmentRepository.watchByClient(any()))
        .thenAnswer((_) => Stream.value(const []));
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        Provider<BarbershopRepository>.value(value: barbershopRepository),
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationRepository>.value(value: notificationRepository),
        Provider<AppointmentRepository>.value(value: appointmentRepository),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('AdminDashboardTab construye sin errores y muestra sus stats', (
    tester,
  ) async {
    authController.profile = const AppUser(
      uid: _uid,
      email: 'a@a.com',
      name: 'Ada',
      role: UserRole.admin,
    );

    await tester.pumpWidget(wrap(const AdminDashboardTab()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hola, Ada 👋'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Control total'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Control total'), findsOneWidget);
  });

  testWidgets(
    'OwnerDashboardTab construye sin errores en estado vacío (sin barbería)',
    (tester) async {
      authController.profile = const AppUser(
        uid: _uid,
        email: 'o@o.com',
        name: 'Oli',
        role: UserRole.owner,
      );

      await tester.pumpWidget(wrap(const OwnerDashboardTab()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hola, Oli 👋'), findsOneWidget);
      expect(find.text('Aún no tienes una barbería'), findsOneWidget);
    },
  );

  testWidgets(
    'OwnerDashboardTab construye sin errores con una barbería aprobada',
    (tester) async {
      authController.profile = const AppUser(
        uid: _uid,
        email: 'o@o.com',
        name: 'Oli',
        role: UserRole.owner,
      );
      final shop = Barbershop(
        id: 'shop1',
        ownerId: _uid,
        name: 'Barbería Central',
        approvalStatus: BarbershopApprovalStatus.approved,
        paymentStatus: PaymentStatus.overdue,
        paymentDueDate: DateTime(2026, 5, 16),
      );
      when(() => barbershopRepository.watchByOwner(_uid))
          .thenAnswer((_) => Stream.value([shop]));

      await tester.pumpWidget(wrap(const OwnerDashboardTab()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Barbería Central'), findsOneWidget);
      expect(find.text('Estado de pago'), findsOneWidget);
    },
  );

  testWidgets('BarberDashboardTab construye sin errores', (tester) async {
    authController.profile = const AppUser(
      uid: _uid,
      email: 'b@b.com',
      name: 'Beto Cruz',
      role: UserRole.barber,
    );

    await tester.pumpWidget(wrap(const BarberDashboardTab()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mi horario'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('La constancia también es talento'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('La constancia también es talento'), findsOneWidget);
  });

  testWidgets('ClientDashboardTab construye sin errores y sin citas próximas', (
    tester,
  ) async {
    authController.profile = const AppUser(
      uid: _uid,
      email: 'c@c.com',
      name: 'Cami',
      role: UserRole.client,
    );

    await tester.pumpWidget(wrap(const ClientDashboardTab()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reservar cita'), findsOneWidget);
    expect(find.text('No tienes citas programadas'), findsOneWidget);
  });

  testWidgets(
    'ClientDashboardTab muestra barberías destacadas cuando hay activas',
    (tester) async {
      authController.profile = const AppUser(
        uid: _uid,
        email: 'c@c.com',
        name: 'Cami',
        role: UserRole.client,
      );
      final shop = Barbershop(
        id: 'shop1',
        ownerId: 'owner1',
        name: 'Barbería Central',
        active: true,
        approvalStatus: BarbershopApprovalStatus.approved,
      );
      when(() => barbershopRepository.watchAll())
          .thenAnswer((_) => Stream.value([shop]));
      when(() => appointmentRepository.watchByClient(_uid)).thenAnswer(
        (_) => Stream.value([
          Appointment(
            id: 'a1',
            barbershopId: 'shop1',
            barberId: 'barber1',
            barberName: 'Beto',
            clientId: _uid,
            clientName: 'Cami',
            serviceId: 'svc1',
            serviceName: 'Corte',
            servicePrice: 20000,
            durationMinutes: 30,
            date: DateTime.now().add(const Duration(days: 1)),
            status: AppointmentStatus.accepted,
          ),
        ]),
      );

      await tester.pumpWidget(wrap(const ClientDashboardTab()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Barbería Central'), findsOneWidget);
      expect(find.text('1 cita(s) programada(s)'), findsOneWidget);
    },
  );
}
