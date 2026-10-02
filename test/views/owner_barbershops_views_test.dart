import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/appointment.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/barbershop/my_barbershops_view.dart';
import 'package:barber/views/barbershop/owner_barbershop_manage_view.dart';
import 'package:barber/views/home/owner_appointments_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

// Vistas de gestión del Dueño: solo sus barberías (+ borradores), sus citas
// y nunca las de otra persona (salvo el admin, que ve todo).

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

const _uid = 'owner1';

AppUser _user(UserRole role, {String uid = _uid}) =>
    AppUser(uid: uid, email: 'o@o.com', name: 'Oli', role: role);

Barbershop _shop(String id, String name, {String ownerId = _uid}) => Barbershop(
  id: id,
  ownerId: ownerId,
  name: name,
  active: true,
  approvalStatus: BarbershopApprovalStatus.approved,
);

Appointment _appointment(String id, String shopId, String client) =>
    Appointment(
      id: id,
      barbershopId: shopId,
      barberId: 'b1',
      barberName: 'Beto',
      clientId: 'c1',
      clientName: client,
      serviceId: 's1',
      serviceName: 'Corte',
      servicePrice: 20000,
      durationMinutes: 30,
      date: DateTime(2030, 1, 1, 10),
    );

void main() {
  late AuthController authController;
  late MockBarbershopRepository barbershops;
  late MockAppointmentRepository appointments;

  setUp(() {
    final authRepository = MockAuthRepository();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    authController = AuthController(
      authService: authRepository,
      userService: MockUserRepository(),
      pushService: MockPushNotificationService(),
    );
    barbershops = MockBarbershopRepository();
    appointments = MockAppointmentRepository();
    when(() => barbershops.watchByOwner(any()))
        .thenAnswer((_) => Stream.value(const []));
    when(() => barbershops.watchDraftsByOwner(any()))
        .thenAnswer((_) => Stream.value(const []));
  });

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: authController),
      Provider<BarbershopRepository>.value(value: barbershops),
      Provider<AppointmentRepository>.value(value: appointments),
    ],
    child: MaterialApp(home: child),
  );

  group('MyBarbershopsView', () {
    testWidgets('lista SOLO las barberías del usuario y sus borradores', (
      tester,
    ) async {
      authController.profile = _user(UserRole.owner);
      when(() => barbershops.watchByOwner(_uid))
          .thenAnswer((_) => Stream.value([_shop('s1', 'Barbería Central')]));
      when(() => barbershops.watchDraftsByOwner(_uid)).thenAnswer(
        (_) => Stream.value([
          Barbershop.fromDraftMap('owner1_1', {
            'name': 'Sede Norte',
            'ownerId': _uid,
          }),
        ]),
      );

      await tester.pumpWidget(wrap(const MyBarbershopsView()));
      await tester.pumpAndSettle();

      expect(find.text('Barbería Central'), findsOneWidget);
      expect(find.text('Sede Norte'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      expect(
        find.textContaining('Borradores (1/$kMaxBarbershopDrafts)'),
        findsOneWidget,
      );
      // Nunca consulta el catálogo ni las barberías de otros.
      verifyNever(() => barbershops.watchAll());
      verifyNever(() => barbershops.watchApproved());
      verify(() => barbershops.watchByOwner(_uid)).called(1);
    });

    testWidgets('sin barberías ni borradores muestra el estado vacío', (
      tester,
    ) async {
      authController.profile = _user(UserRole.owner);

      await tester.pumpWidget(wrap(const MyBarbershopsView()));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes barberías'), findsOneWidget);
      expect(find.text('Nueva barbería'), findsOneWidget);
    });
  });

  group('OwnerBarbershopManageView', () {
    testWidgets('el dueño gestiona su propia barbería', (tester) async {
      authController.profile = _user(UserRole.owner);
      when(() => barbershops.watchOne('s1'))
          .thenAnswer((_) => Stream.value(_shop('s1', 'Barbería Central')));

      await tester.pumpWidget(
        wrap(const OwnerBarbershopManageView(barbershopId: 's1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar datos'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Citas de esta barbería'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      // Los tiles nuevos arrancan su animación de entrada con un timer.
      await tester.pumpAndSettle();
      expect(find.text('Citas de esta barbería'), findsOneWidget);
    });

    testWidgets('alerta y ofrece pagar cuando la mensualidad está vencida', (
      tester,
    ) async {
      authController.profile = _user(UserRole.owner);
      final overdue = Barbershop(
        id: 's1',
        ownerId: _uid,
        name: 'Barbería Central',
        active: true,
        approvalStatus: BarbershopApprovalStatus.approved,
        paymentStatus: PaymentStatus.overdue,
        paymentDueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      when(() => barbershops.watchOne('s1'))
          .thenAnswer((_) => Stream.value(overdue));

      await tester.pumpWidget(
        wrap(const OwnerBarbershopManageView(barbershopId: 's1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mensualidad vencida'), findsOneWidget);
      expect(
        find.text('Pagar ${formatCop(kBarbershopMonthlyFee)}'),
        findsWidgets,
      );
    });

    testWidgets(
      'bloqueada (cancelada o en mora): alerta, ofrece pagar y se puede eliminar',
      (tester) async {
        authController.profile = _user(UserRole.owner);
        final blocked = Barbershop(
          id: 's1',
          ownerId: _uid,
          name: 'Barbería Central',
          active: false,
          approvalStatus: BarbershopApprovalStatus.approved,
          paymentStatus: PaymentStatus.blocked,
        );
        when(() => barbershops.watchOne('s1'))
            .thenAnswer((_) => Stream.value(blocked));

        await tester.pumpWidget(
          wrap(const OwnerBarbershopManageView(barbershopId: 's1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bloqueada'), findsWidgets);
        expect(
          find.text('Pagar ${formatCop(kBarbershopMonthlyFee)}'),
          findsWidgets,
        );
        expect(OwnerBarbershopManageView.canDelete(blocked), isTrue);
      },
    );

    testWidgets(
      'pendiente de aprobación: no deja eliminar una barbería aprobada y viva',
      (tester) async {
        final live = Barbershop(
          id: 's1',
          ownerId: _uid,
          name: 'Viva',
          active: true,
          approvalStatus: BarbershopApprovalStatus.approved,
        );
        final pending = Barbershop(
          id: 's2',
          ownerId: _uid,
          name: 'Pendiente',
          approvalStatus: BarbershopApprovalStatus.pending,
        );
        expect(OwnerBarbershopManageView.canDelete(live), isFalse);
        expect(OwnerBarbershopManageView.canDelete(pending), isTrue);
      },
    );

    testWidgets('NO deja gestionar la barbería de otro dueño', (tester) async {
      authController.profile = _user(UserRole.owner);
      when(() => barbershops.watchOne('s9')).thenAnswer(
        (_) => Stream.value(_shop('s9', 'Ajena', ownerId: 'otro-dueño')),
      );

      await tester.pumpWidget(
        wrap(const OwnerBarbershopManageView(barbershopId: 's9')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No puedes gestionar esta barbería'), findsOneWidget);
      expect(find.text('Editar datos'), findsNothing);
    });

    testWidgets('el admin gestiona cualquier barbería', (tester) async {
      authController.profile = _user(UserRole.admin, uid: 'admin1');
      when(() => barbershops.watchOne('s9')).thenAnswer(
        (_) => Stream.value(_shop('s9', 'Ajena', ownerId: 'otro-dueño')),
      );

      await tester.pumpWidget(
        wrap(const OwnerBarbershopManageView(barbershopId: 's9')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar datos'), findsOneWidget);
    });
  });

  group('OwnerAppointmentsTab (Mis citas)', () {
    testWidgets('muestra las citas agendadas en TODAS sus barberías', (
      tester,
    ) async {
      authController.profile = _user(UserRole.owner);
      when(() => barbershops.watchByOwner(_uid)).thenAnswer(
        (_) => Stream.value([_shop('s1', 'Central'), _shop('s2', 'Norte')]),
      );
      when(() => appointments.watchByBarbershops(any())).thenAnswer(
        (_) => Stream.value([
          _appointment('a1', 's1', 'Ana'),
          _appointment('a2', 's2', 'Luis'),
        ]),
      );

      await tester.pumpWidget(wrap(const OwnerAppointmentsTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ana con Beto'), findsOneWidget);
      expect(find.textContaining('Luis con Beto'), findsOneWidget);
      verify(() => appointments.watchByBarbershops(['s1', 's2']))
          .called(greaterThanOrEqualTo(1));

      // Filtrar por una barbería solo consulta esa.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Norte'));
      await tester.pumpAndSettle();
      verify(() => appointments.watchByBarbershops(['s2'])).called(1);
    });
  });
}
