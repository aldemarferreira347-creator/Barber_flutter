import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/appointment.dart';
import 'package:barber/models/comment.dart';
import 'package:barber/models/day_schedule.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/comment_repository.dart';
import 'package:barber/repositories/rating_repository.dart';
import 'package:barber/repositories/shop_closure_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/admin/manage_users_view.dart';
import 'package:barber/views/admin/user_forms.dart';
import 'package:barber/views/appointment/paid_appointment_sheets.dart';
import 'package:barber/views/appointment/rate_appointment_view.dart';
import 'package:barber/views/barber/manage_barbers_view.dart';
import 'package:barber/views/barbershop/close_shop_view.dart';
import 'package:barber/views/barbershop/edit_schedule_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Pantallas de gestión rediseñadas: usuarios (admin), barberos, cierre y
// horario de la barbería y calificación de una cita.

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

class MockShopClosureRepository extends Mock implements ShopClosureRepository {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockCommentRepository extends Mock implements CommentRepository {}

AppUser _user(String uid, String name, UserRole role, {bool active = true}) =>
    AppUser(
      uid: uid,
      email: '$uid@barber.test',
      name: name,
      role: role,
      active: active,
    );

void main() {
  late MockUserRepository users;
  late AuthController auth;

  setUpAll(() {
    registerFallbackValue(UserRole.client);
    registerFallbackValue(<String, DaySchedule>{});
  });

  /// Pantalla alta: los formularios largos caben sin desplazarse.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    users = MockUserRepository();
    final authRepository = MockAuthRepository();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    auth = AuthController(
      authService: authRepository,
      userService: users,
      pushService: MockPushNotificationService(),
    )..profile = _user('admin1', 'Ada Admin', UserRole.admin);
  });

  Widget wrap(Widget child, {List<SingleChildWidget> providers = const []}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<UserRepository>.value(value: users),
          ...providers,
        ],
        child: MaterialApp(home: child),
      );

  group('ManageUsersView', () {
    setUp(() {
      when(() => users.watchAll()).thenAnswer(
        (_) => Stream.value([
          _user('admin1', 'Ada Admin', UserRole.admin),
          _user('c1', 'Carla Cliente', UserRole.client),
          _user('b1', 'Beto Barbero', UserRole.barber),
        ]),
      );
    });

    testWidgets('lista, filtra por rol y no deja actuar sobre uno mismo', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ManageUsersView()));
      await tester.pumpAndSettle();

      expect(find.text('Carla Cliente'), findsOneWidget);
      expect(find.text('Beto Barbero'), findsOneWidget);
      // Solo las otras dos filas ofrecen el menú de acciones.
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Barbero'));
      await tester.pumpAndSettle();
      expect(find.text('Beto Barbero'), findsOneWidget);
      expect(find.text('Carla Cliente'), findsNothing);
    });

    testWidgets('buscar sin resultados lo explica', (tester) async {
      tall(tester);
      await tester.pumpWidget(wrap(const ManageUsersView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No se encontraron usuarios'), findsOneWidget);
    });

    testWidgets(
      'cambiar el rol pide confirmación y guarda UNA sola escritura',
      (tester) async {
        tall(tester);
        when(
          () => users.updateProfile(
            any(),
            name: any(named: 'name'),
            email: any(named: 'email'),
            role: any(named: 'role'),
          ),
        ).thenAnswer((_) async {});
        await tester.pumpWidget(wrap(const ManageUsersView()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Carla Cliente'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar usuario'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(EditUserForm),
            matching: find.widgetWithText(ChoiceChip, 'Barbero'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar cambios'));
        // El botón muestra su indicador mientras espera la confirmación
        // (animación infinita): se avanza el tiempo sin esperar a que pare.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Confirmación del cambio de rol.
        expect(find.text('Cambiar rol'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Cambiar rol'));
        await tester.pumpAndSettle();

        verify(() => users.updateProfile('c1', role: UserRole.barber))
            .called(1);
        expect(find.text('Usuario actualizado'), findsOneWidget);
      },
    );

    testWidgets('desactivar pide confirmación y no escribe si se cancela', (
      tester,
    ) async {
      when(() => users.setActive(any(), any())).thenAnswer((_) async {});
      await tester.pumpWidget(wrap(const ManageUsersView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carla Cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      verifyNever(() => users.setActive(any(), any()));

      await tester.tap(find.text('Carla Cliente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
      await tester.pumpAndSettle();
      verify(() => users.setActive('c1', false)).called(1);
    });
  });

  group('ManageBarbersView', () {
    setUp(() {
      when(
        () => users.watchBarbersByBarbershop(any()),
      ).thenAnswer((_) => Stream.value([_user('b1', 'Beto', UserRole.barber)]));
    });

    Future<void> hire(WidgetTester tester, String email) async {
      await tester.pumpWidget(
        wrap(const ManageBarbersView(barbershopId: 'shop1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contratar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), email);
      await tester.tap(find.text('Buscar'));
      await tester.pumpAndSettle();
    }

    testWidgets('un correo inválido se explica sin buscar', (tester) async {
      tall(tester);
      await hire(tester, 'esto-no-es-un-correo');
      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      verifyNever(() => users.findByEmail(any()));
    });

    testWidgets('un correo sin cuenta se explica en la misma hoja', (
      tester,
    ) async {
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      await hire(tester, 'nadie@barber.test');
      expect(find.textContaining('No existe ninguna cuenta'), findsOneWidget);
    });

    testWidgets('quien ya tiene otro rol no se puede contratar', (
      tester,
    ) async {
      when(() => users.findByEmail(any()))
          .thenAnswer((_) async => _user('o1', 'Olga', UserRole.owner));
      await hire(tester, 'olga@barber.test');
      expect(find.textContaining('ya tiene otro rol'), findsOneWidget);
      verifyNever(
        () => users.hireAsBarber(
          uid: any(named: 'uid'),
          barbershopId: any(named: 'barbershopId'),
        ),
      );
    });

    testWidgets('un cliente se contrata solo tras confirmar', (tester) async {
      tall(tester);
      when(() => users.findByEmail(any()))
          .thenAnswer((_) async => _user('c1', 'Carla', UserRole.client));
      when(
        () => users.hireAsBarber(
          uid: any(named: 'uid'),
          barbershopId: any(named: 'barbershopId'),
        ),
      ).thenAnswer((_) async {});
      await hire(tester, 'c1@barber.test');

      verifyNever(
        () => users.hireAsBarber(
          uid: any(named: 'uid'),
          barbershopId: any(named: 'barbershopId'),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Contratar'));
      await tester.pumpAndSettle();
      verify(() => users.hireAsBarber(uid: 'c1', barbershopId: 'shop1'))
          .called(1);
    });
  });

  group('CloseShopView', () {
    testWidgets('sin fechas ni motivo no cierra y lo explica', (tester) async {
      tall(tester);
      final closures = MockShopClosureRepository();
      await tester.pumpWidget(
        wrap(
          const CloseShopView(barbershopId: 'shop1'),
          providers: [Provider<ShopClosureRepository>.value(value: closures)],
        ),
      );

      await tester.tap(find.text('Confirmar cierre'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Elige desde cuándo'), findsOneWidget);
      verifyNever(
        () => closures.closeForExternalEvent(
          barbershopId: any(named: 'barbershopId'),
          closedFrom: any(named: 'closedFrom'),
          closedUntil: any(named: 'closedUntil'),
          reason: any(named: 'reason'),
        ),
      );
    });

    testWidgets('ya no promete avisos que el sistema no envía', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        wrap(
          const CloseShopView(barbershopId: 'shop1'),
          providers: [
            Provider<ShopClosureRepository>.value(
              value: MockShopClosureRepository(),
            ),
          ],
        ),
      );
      expect(find.textContaining('notificó'), findsNothing);
      expect(find.textContaining('reprogramar'), findsOneWidget);
    });
  });

  group('EditScheduleView', () {
    testWidgets('un cierre anterior a la apertura no se guarda', (
      tester,
    ) async {
      final shops = MockBarbershopRepository();
      final schedule = weekScheduleFromMap(null);
      schedule['lunes'] = const DaySchedule(
        openTime: '18:00',
        closeTime: '08:00',
      );
      await tester.pumpWidget(
        wrap(
          EditScheduleView(barbershopId: 'shop1', initialSchedule: schedule),
          providers: [Provider<BarbershopRepository>.value(value: shops)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Guardar horarios'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar horarios'));
      await tester.pumpAndSettle();

      expect(find.textContaining('posterior a la de apertura'), findsOneWidget);
      verifyNever(() => shops.updateSchedule(any(), any()));
    });
  });

  group('RateAppointmentView', () {
    final appointment = Appointment(
      id: 'a1',
      barbershopId: 'shop1',
      barberId: 'b1',
      barberName: 'Beto',
      clientId: 'c1',
      clientName: 'Carla',
      serviceId: 's1',
      serviceName: 'Corte',
      servicePrice: 20000,
      durationMinutes: 30,
      date: DateTime(2030, 1, 1, 10),
    );

    testWidgets(
      'si el comentario falla la calificación ya quedó guardada y no se repite',
      (tester) async {
        tall(tester);
        final ratings = MockRatingRepository();
        final comments = MockCommentRepository();
        when(
          () => ratings.submitRating(
            appointmentId: any(named: 'appointmentId'),
            barberStars: any(named: 'barberStars'),
            shopStars: any(named: 'shopStars'),
          ),
        ).thenAnswer((_) async {});
        var attempts = 0;
        when(
          () => comments.submitComment(
            appointmentId: any(named: 'appointmentId'),
            text: any(named: 'text'),
            photoUrl: any(named: 'photoUrl'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw Exception('sin red');
          return CommentStatus.published;
        });

        await tester.pumpWidget(
          wrap(
            RateAppointmentView(appointment: appointment),
            providers: [
              Provider<RatingRepository>.value(value: ratings),
              Provider<CommentRepository>.value(value: comments),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Una estrella por cada selector (barbero y barbería).
        await tester.tap(find.byTooltip('5 estrellas').first);
        await tester.tap(find.byTooltip('4 estrellas').last);
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextField, 'Comentario (opcional)'),
          'Excelente corte',
        );
        await tester.ensureVisible(find.text('Enviar calificación'));
        await tester.tap(find.text('Enviar calificación'));
        await tester.pumpAndSettle();

        expect(find.textContaining('ya se guardó'), findsOneWidget);
        expect(find.text('Reenviar comentario'), findsOneWidget);
        verify(
          () => ratings.submitRating(
            appointmentId: 'a1',
            barberStars: 5,
            shopStars: 4,
          ),
        ).called(1);

        await tester.tap(find.text('Reenviar comentario'));
        await tester.pumpAndSettle();

        // Calificar de nuevo no se intenta: solo se reenvía el comentario.
        verifyNever(
          () => ratings.submitRating(
            appointmentId: 'a1',
            barberStars: 5,
            shopStars: 4,
          ),
        );
        expect(attempts, 2);
      },
    );
  });

  group('PostponeForm', () {
    final paid = Appointment(
      id: 'a1',
      barbershopId: 'shop1',
      barberId: 'b1',
      barberName: 'Beto',
      clientId: 'c1',
      clientName: 'Carla',
      serviceId: 's1',
      serviceName: 'Corte',
      servicePrice: 20000,
      durationMinutes: 30,
      date: DateTime(2030, 1, 1, 10),
      paid: true,
    );

    Future<MockAppointmentRepository> open(WidgetTester tester) async {
      tall(tester);
      final appointments = MockAppointmentRepository();
      final shops = MockBarbershopRepository();
      when(() => shops.watchOne('shop1')).thenAnswer(
        (_) => Stream.value(
          const Barbershop(
            id: 'shop1',
            ownerId: 'o1',
            name: 'Barbería Uno',
            active: true,
            approvalStatus: BarbershopApprovalStatus.approved,
          ),
        ),
      );
      await tester.pumpWidget(
        wrap(
          Scaffold(body: PostponeForm(appointment: paid)),
          providers: [
            Provider<AppointmentRepository>.value(value: appointments),
            Provider<BarbershopRepository>.value(value: shops),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return appointments;
    }

    testWidgets('solo ofrece horas dentro del horario y mueve la cita', (
      tester,
    ) async {
      final appointments = await open(tester);
      when(() => appointments.postponePaid(any(), any()))
          .thenAnswer((_) async {});

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mañana'));
      await tester.pumpAndSettle();
      // Horario por defecto 08:00–18:00: nada de madrugada ni de noche.
      expect(find.widgetWithText(ChoiceChip, '03:00'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, '22:00'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.pump();
      await tester.tap(find.text('Confirmar nuevo horario'));
      await tester.pump();

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      verify(
        () => appointments.postponePaid(
          'a1',
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
        ),
      ).called(1);
    });

    testWidgets('sin elegir hora no escribe y lo explica', (tester) async {
      final appointments = await open(tester);

      await tester.tap(find.text('Confirmar nuevo horario'));
      await tester.pumpAndSettle();

      expect(find.text('Elige el nuevo día y hora.'), findsOneWidget);
      verifyNever(() => appointments.postponePaid(any(), any()));
    });

    testWidgets('si el horario ya fue tomado, lo dice en la misma hoja', (
      tester,
    ) async {
      final appointments = await open(tester);
      when(() => appointments.postponePaid(any(), any())).thenAnswer(
        (_) async =>
            throw Exception('Ese nuevo horario ya no está disponible.'),
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Mañana'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '10:00'));
      await tester.pump();
      await tester.tap(find.text('Confirmar nuevo horario'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ese nuevo horario ya no está disponible.'),
        findsOneWidget,
      );
    });
  });
}
