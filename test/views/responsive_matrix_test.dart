import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_notification.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/appointment.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/models/payment_record.dart';
import 'package:barber/models/platform_settings.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/notification_repository.dart';
import 'package:barber/repositories/payment_repository.dart';
import 'package:barber/repositories/platform_settings_repository.dart';
import 'package:barber/repositories/rating_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/theme/app_colors.dart';
import 'package:barber/theme/app_theme.dart';
import 'package:barber/views/admin/manage_users_view.dart';
import 'package:barber/views/appointment/client_appointments_view.dart';
import 'package:barber/views/barbershop/my_barbershops_view.dart';
import 'package:barber/views/barbershop/owner_report_view.dart';
import 'package:barber/views/help/help_view.dart';
import 'package:barber/views/home/admin_dashboard_tab.dart';
import 'package:barber/views/home/barber_dashboard_tab.dart';
import 'package:barber/views/home/client_dashboard_tab.dart';
import 'package:barber/views/home/owner_dashboard_tab.dart';
import 'package:barber/views/notification/notifications_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Matriz responsive: las pantallas principales de los 4 roles se montan con
// datos "difíciles" (nombres y correos largos, cifras grandes) en 4 tamaños
// de pantalla, claro y oscuro, y letra al 100 % y al 150 %. Cualquier
// desbordamiento (RenderFlex overflow) o excepción de layout hace fallar la
// prueba: es el tipo de error que `flutter analyze` no ve.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockPlatformSettingsRepository extends Mock
    implements PlatformSettingsRepository {}

const _uid = 'user1';
const _longName = 'Barbería Central de la Avenida Principal Norte';
const _longEmail =
    'una.persona.con.un.correo.muy.largo@barberflow-ejemplo.test';

const _sizes = <(String, Size)>[
  ('320x640', Size(320, 640)),
  ('390x844', Size(390, 844)),
  ('768x1024', Size(768, 1024)),
  ('1280x800', Size(1280, 800)),
];

void main() {
  late AuthController auth;
  late MockBarbershopRepository shops;
  late MockUserRepository users;
  late MockNotificationRepository notifications;
  late MockAppointmentRepository appointments;
  late MockPaymentRepository payments;
  late MockRatingRepository ratings;
  late MockPlatformSettingsRepository settings;

  final shop = Barbershop(
    id: 'shop1',
    ownerId: _uid,
    name: _longName,
    address: 'Carrera 100 con Calle 200, Barrio Las Américas, Bogotá D.C.',
    active: true,
    approvalStatus: BarbershopApprovalStatus.approved,
    paymentDueDate: DateTime(2026, 11, 20),
    ratingCount: 120,
    ratingSum: 540,
  );

  Appointment appointment(
    String id,
    DateTime date, {
    AppointmentStatus status = AppointmentStatus.completed,
    bool paid = true,
  }) => Appointment(
    id: id,
    barbershopId: 'shop1',
    barberId: 'b1',
    barberName: 'Carlos Alberto Pérez de la Torre',
    clientId: 'c1',
    clientName: 'Juan Sebastián Rodríguez Castellanos',
    serviceId: 's1',
    serviceName: 'Corte clásico con barba y toalla caliente',
    servicePrice: 1250000,
    durationMinutes: 60,
    date: date,
    status: status,
    paid: paid,
  );

  setUp(() {
    final authRepository = MockAuthRepository();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    auth = AuthController(
      authService: authRepository,
      userService: MockUserRepository(),
      pushService: MockPushNotificationService(),
    );
    shops = MockBarbershopRepository();
    users = MockUserRepository();
    notifications = MockNotificationRepository();
    appointments = MockAppointmentRepository();
    payments = MockPaymentRepository();
    ratings = MockRatingRepository();
    settings = MockPlatformSettingsRepository();

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final lastWeek = DateTime.now().subtract(const Duration(days: 2));
    final list = [
      appointment('a1', lastWeek),
      appointment('a2', lastWeek, status: AppointmentStatus.cancelled),
      appointment('a3', tomorrow, status: AppointmentStatus.accepted),
      appointment('a4', tomorrow, status: AppointmentStatus.pending),
    ];

    when(() => shops.watchAll()).thenAnswer((_) => Stream.value([shop, shop]));
    when(() => shops.watchApproved()).thenAnswer((_) => Stream.value([shop]));
    when(() => shops.watchByOwner(any())).thenAnswer(
      (_) => Stream.value([
        shop,
        const Barbershop(
          id: 'shop2',
          ownerId: _uid,
          name: 'Barbería Norte',
          active: true,
        ),
      ]),
    );
    when(() => shops.watchDraftsByOwner(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => shops.watchOne(any())).thenAnswer((_) => Stream.value(shop));
    when(() => users.watchAll()).thenAnswer(
      (_) => Stream.value([
        const AppUser(
          uid: _uid,
          email: 'a@a.com',
          name: 'Ada Admin',
          role: UserRole.admin,
        ),
        const AppUser(
          uid: 'u2',
          email: _longEmail,
          name: 'Una Persona Con Un Nombre Realmente Muy Largo Apellidoso',
          role: UserRole.owner,
        ),
        const AppUser(
          uid: 'u3',
          email: 'inactivo@a.com',
          name: 'Inactivo',
          role: UserRole.barber,
          active: false,
        ),
      ]),
    );
    when(() => appointments.watchByClient(any()))
        .thenAnswer((_) => Stream.value(list));
    when(() => appointments.watchByBarber(any()))
        .thenAnswer((_) => Stream.value(list));
    when(() => appointments.watchByBarbershops(any()))
        .thenAnswer((_) => Stream.value(list));
    when(() => notifications.watchForUser(any())).thenAnswer(
      (_) => Stream.value([
        AppNotification(
          id: 'n1',
          toUserId: _uid,
          title: 'Aviso importante sobre el pago de tu mensualidad atrasada',
          body:
              'Tu barbería tiene un pago pendiente desde hace varios días y '
              'se bloqueará si no lo regularizas pronto con el administrador.',
          type: NotificationType.autoPaymentOverdue,
          createdAt: DateTime.now(),
        ),
        const AppNotification(
          id: 'n2',
          toUserId: _uid,
          title: 'Leída',
          body: 'Ya la viste.',
          read: true,
        ),
      ]),
    );
    when(() => payments.watchPendingSubscriptions())
        .thenAnswer((_) => Stream.value(const <PaymentRecord>[]));
    when(() => ratings.watchRatedAppointmentIds(any()))
        .thenAnswer((_) => Stream.value(const <String>{}));
    when(() => settings.watch()).thenAnswer(
      (_) => Stream.value(const PlatformSettings(nequiPhone: '3001234567')),
    );
  });

  tearDown(() => AppColors.isDark = false);

  Widget app(Widget child, {required bool dark, required double scale}) {
    AppColors.isDark = dark;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        Provider<BarbershopRepository>.value(value: shops),
        Provider<UserRepository>.value(value: users),
        Provider<NotificationRepository>.value(value: notifications),
        Provider<AppointmentRepository>.value(value: appointments),
        Provider<PaymentRepository>.value(value: payments),
        Provider<RatingRepository>.value(value: ratings),
        Provider<PlatformSettingsRepository>.value(value: settings),
      ],
      child: MaterialApp(
        theme: AppTheme.current,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
  }

  /// Monta [build] en toda la matriz y falla con el combo exacto que rompe.
  Future<void> expectNoOverflow(
    WidgetTester tester,
    String name,
    AppUser profile,
    Widget Function() build,
  ) async {
    auth.profile = profile;
    addTearDown(tester.view.reset);
    final reported = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) =>
        reported.add(details.toString().split('\n').take(14).join('\n'));
    try {
      for (final (sizeName, size) in _sizes) {
        for (final dark in [false, true]) {
          for (final scale in [1.0, 1.5]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              KeyedSubtree(
                key: UniqueKey(),
                child: app(build(), dark: dark, scale: scale),
              ),
            );
            await tester.pumpAndSettle();
            tester.takeException();
            expect(
              reported,
              isEmpty,
              reason:
                  '$name se desborda en $sizeName, '
                  '${dark ? 'oscuro' : 'claro'}, letra x$scale:'
                  '\n${reported.isEmpty ? '' : reported.first}',
            );
          }
        }
      }
    } finally {
      FlutterError.onError = original;
    }
  }

  const client = AppUser(
    uid: _uid,
    email: 'c@c.com',
    name: 'Cami Rodríguez',
    role: UserRole.client,
  );
  const owner = AppUser(
    uid: _uid,
    email: 'o@o.com',
    name: 'Oli Dueño',
    role: UserRole.owner,
  );
  const barber = AppUser(
    uid: _uid,
    email: 'b@b.com',
    name: 'Beto Cruz',
    role: UserRole.barber,
  );
  const admin = AppUser(
    uid: _uid,
    email: 'a@a.com',
    name: 'Ada Admin',
    role: UserRole.admin,
  );

  testWidgets('Cliente: inicio', (tester) async {
    await expectNoOverflow(
      tester,
      'ClientDashboardTab',
      client,
      () => const ClientDashboardTab(),
    );
  });

  testWidgets('Cliente: mis citas', (tester) async {
    await expectNoOverflow(
      tester,
      'ClientAppointmentsView',
      client,
      () => const ClientAppointmentsView(),
    );
  });

  testWidgets('Dueño: inicio', (tester) async {
    await expectNoOverflow(
      tester,
      'OwnerDashboardTab',
      owner,
      () => const OwnerDashboardTab(),
    );
  });

  testWidgets('Dueño: mis barberías', (tester) async {
    await expectNoOverflow(
      tester,
      'MyBarbershopsView',
      owner,
      () => const MyBarbershopsView(),
    );
  });

  testWidgets('Dueño: informe', (tester) async {
    await expectNoOverflow(
      tester,
      'OwnerReportView',
      owner,
      () => const OwnerReportView(),
    );
  });

  testWidgets('Barbero: inicio', (tester) async {
    await expectNoOverflow(
      tester,
      'BarberDashboardTab',
      barber,
      () => const BarberDashboardTab(),
    );
  });

  testWidgets('Admin: inicio', (tester) async {
    await expectNoOverflow(
      tester,
      'AdminDashboardTab',
      admin,
      () => const AdminDashboardTab(),
    );
  });

  testWidgets('Admin: usuarios', (tester) async {
    await expectNoOverflow(
      tester,
      'ManageUsersView',
      admin,
      () => const ManageUsersView(),
    );
  });

  testWidgets('Todos: notificaciones y ayuda', (tester) async {
    await expectNoOverflow(
      tester,
      'NotificationsView',
      client,
      () => const NotificationsView(uid: _uid),
    );
    await expectNoOverflow(tester, 'HelpView', client, () => const HelpView());
  });
}
