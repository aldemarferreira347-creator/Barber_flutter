import 'package:barber/controllers/user_controller.dart';
import 'package:barber/models/app_user.dart';
import 'package:barber/models/user_role.dart';
import 'package:barber/repositories/barber_availability_repository.dart';
import 'package:barber/repositories/user_repository.dart';
import 'package:barber/views/barber/barber_availability_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockBarberAvailabilityRepository extends Mock implements BarberAvailabilityRepository {}

const _kUid = 'barber1';

void main() {
  late UserController userController;
  late MockBarberAvailabilityRepository availabilityRepository;

  setUp(() {
    userController = UserController(userService: MockUserRepository());
    availabilityRepository = MockBarberAvailabilityRepository();
  });

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserController>.value(value: userController),
        Provider<BarberAvailabilityRepository>.value(value: availabilityRepository),
      ],
      child: const MaterialApp(home: BarberAvailabilityView()),
    );
  }

  testWidgets('cuando no está afuera, ofrece elegir un estimado y marcar salida', (tester) async {
    userController.profile = const AppUser(uid: _kUid, email: 'b@b.com', name: 'Beto', role: UserRole.barber);
    when(() => availabilityRepository.markAway(any())).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('¿Vas a salir de la tienda?'), findsOneWidget);
    expect(find.text('Marcar salida'), findsOneWidget);
    expect(find.text('Marcar regreso'), findsNothing);

    await tester.tap(find.text('45 min'));
    await tester.pump();
    await tester.tap(find.text('Marcar salida'));
    await tester.pumpAndSettle();

    verify(() => availabilityRepository.markAway(45)).called(1);
  });

  testWidgets('cuando está afuera, muestra el estimado y ofrece marcar regreso', (tester) async {
    final estimate = DateTime(2026, 1, 1, 15, 30);
    userController.profile = AppUser(
      uid: _kUid,
      email: 'b@b.com',
      name: 'Beto',
      role: UserRole.barber,
      awaySince: DateTime(2026, 1, 1, 15, 0),
      awayUntilEstimate: estimate,
    );
    when(() => availabilityRepository.markReturned()).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Estás fuera de la tienda'), findsOneWidget);
    expect(find.textContaining('15:30'), findsOneWidget);
    expect(find.text('Marcar salida'), findsNothing);

    await tester.tap(find.text('Marcar regreso'));
    await tester.pumpAndSettle();

    verify(() => availabilityRepository.markReturned()).called(1);
  });
}
