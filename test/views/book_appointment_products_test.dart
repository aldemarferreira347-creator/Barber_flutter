import 'package:barber/controllers/auth_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/barbershop.dart';
import 'package:barber/models/product.dart';
import 'package:barber/models/service.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/appointment_repository.dart';
import 'package:barber/repositories/auth_repository.dart';
import 'package:barber/repositories/barbershop_repository.dart';
import 'package:barber/repositories/product_repository.dart';
import 'package:barber/repositories/purchase_repository.dart';
import 'package:barber/repositories/service_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/services/push_notification_service.dart';
import 'package:barber/views/appointment/book_appointment_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockPush extends Mock implements PushNotificationService {}

class MockBarbershopRepository extends Mock implements BarbershopRepository {}

class MockServiceRepository extends Mock implements ServiceRepository {}

class MockProductRepository extends Mock implements ProductRepository {}

class MockAppointmentRepository extends Mock implements AppointmentRepository {}

class MockPurchaseRepository extends Mock implements PurchaseRepository {}

const _shop = Barbershop(
  id: 'shop1',
  name: 'BarberFlow',
  ownerId: 'owner1',
  nequiPhone: '3001234567',
  active: true,
  approvalStatus: BarbershopApprovalStatus.approved,
);

void main() {
  late AuthController auth;
  late MockBarbershopRepository shops;
  late MockServiceRepository services;
  late MockProductRepository products;
  late MockUserRepository users;

  setUp(() {
    final authRepo = MockAuthRepository();
    final push = MockPush();
    users = MockUserRepository();
    when(() => authRepo.authStateChanges)
        .thenAnswer((_) => const Stream<User?>.empty());
    when(() => push.onTokenRefresh)
        .thenAnswer((_) => const Stream<String>.empty());
    auth = AuthController(
      authService: authRepo,
      userService: users,
      pushService: push,
    );
    auth.profile = const AppUser(
      uid: 'c1',
      email: 'c@x.com',
      name: 'Ana',
      role: UserRole.client,
    );
    shops = MockBarbershopRepository();
    services = MockServiceRepository();
    products = MockProductRepository();
    when(() => shops.watchOne('shop1')).thenAnswer((_) => Stream.value(_shop));
    when(() => services.watchByBarbershop('shop1')).thenAnswer(
      (_) => Stream.value(const [
        Service(
          id: 's1',
          barbershopId: 'shop1',
          name: 'Corte',
          price: 20000,
          durationMinutes: 30,
        ),
      ]),
    );
    when(() => users.watchBarbersByBarbershop('shop1')).thenAnswer(
      (_) => Stream.value(const [
        AppUser(
          uid: 'b1',
          email: 'b@x.com',
          name: 'Beto',
          role: UserRole.barber,
        ),
      ]),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<BarbershopRepository>.value(value: shops),
          Provider<ServiceRepository>.value(value: services),
          Provider<ProductRepository>.value(value: products),
          Provider<UserRepository>.value(value: users),
          Provider<AppointmentRepository>.value(
            value: MockAppointmentRepository(),
          ),
          Provider<PurchaseRepository>.value(value: MockPurchaseRepository()),
        ],
        child: const MaterialApp(
          home: BookAppointmentView(
            barbershopId: 'shop1',
            barbershopName: 'BarberFlow',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin productos el paso de productos no aparece (no es error)', (
    tester,
  ) async {
    when(() => products.watchByBarbershop('shop1'))
        .thenAnswer((_) => Stream.value(const []));

    await pump(tester);

    expect(find.text('1. Elige un servicio'), findsOneWidget);
    expect(find.textContaining('Agrega productos'), findsNothing);
    expect(find.textContaining('No pudimos'), findsNothing);
  });

  testWidgets('con productos se pueden agregar y quitar, y el agotado no', (
    tester,
  ) async {
    when(() => products.watchByBarbershop('shop1')).thenAnswer(
      (_) => Stream.value(const [
        Product(
          id: 'p1',
          barbershopId: 'shop1',
          name: 'Cera',
          price: 15000,
          stock: 2,
        ),
        Product(
          id: 'p2',
          barbershopId: 'shop1',
          name: 'Aceite',
          price: 30000,
          stock: 0,
        ),
      ]),
    );

    await pump(tester);

    expect(find.text('4. Agrega productos (opcional)'), findsOneWidget);
    expect(find.textContaining('Agotado'), findsOneWidget);

    await tester.tap(find.byTooltip('Agregar Cera'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byTooltip('Agregar Cera'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // Solo quedaban 2: no se puede pasar del stock.
    IconButton buttonOf(String tooltip) => tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(buttonOf('Agregar Cera').onPressed, isNull);

    // El agotado no se puede agregar.
    expect(buttonOf('Agregar Aceite').onPressed, isNull);

    await tester.tap(find.byTooltip('Quitar uno'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
