import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/user_controller.dart';
import 'firebase_options.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/barber_availability_repository.dart';
import 'repositories/barbershop_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/payment_repository.dart';
import 'repositories/comment_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/purchase_repository.dart';
import 'repositories/rating_repository.dart';
import 'repositories/refund_request_repository.dart';
import 'repositories/service_repository.dart';
import 'repositories/shop_closure_repository.dart';
import 'repositories/storage_repository.dart';
import 'repositories/user_repository.dart';
import 'routes/app_router.dart';
import 'services/cloud_barber_availability_service.dart';
import 'services/cloud_comment_service.dart';
import 'services/cloud_purchase_service.dart';
import 'services/cloud_rating_service.dart';
import 'services/cloud_refund_request_service.dart';
import 'services/cloud_shop_closure_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_storage_service.dart';
import 'services/firestore_appointment_service.dart';
import 'services/firestore_barbershop_service.dart';
import 'services/firestore_notification_service.dart';
import 'services/firestore_product_service.dart';
import 'services/firestore_service_service.dart';
import 'services/firestore_user_service.dart';
import 'services/nequi_payment_gateway.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BarberApp());
}

class BarberApp extends StatelessWidget {
  const BarberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositorios (infraestructura Firebase) expuestos por su
        // abstracción: el resto de la app depende de la interfaz, no de
        // Firebase directamente (Dependency Inversion).
        Provider<AuthRepository>(create: (_) => FirebaseAuthService()),
        Provider<UserRepository>(create: (_) => FirestoreUserService()),
        Provider<StorageRepository>(create: (_) => FirebaseStorageService()),
        ProxyProvider<StorageRepository, BarbershopRepository>(
          update: (_, storage, _) => FirestoreBarbershopService(storage: storage),
        ),
        ProxyProvider<StorageRepository, ServiceRepository>(
          update: (_, storage, _) => FirestoreServiceService(storage: storage),
        ),
        Provider<AppointmentRepository>(create: (_) => FirestoreAppointmentService()),
        Provider<NotificationRepository>(create: (_) => FirestoreNotificationService()),
        Provider<PaymentGateway>(create: (_) => NequiPaymentGateway()),
        Provider<PurchaseRepository>(create: (_) => CloudPurchaseService()),
        Provider<RefundRequestRepository>(create: (_) => CloudRefundRequestService()),
        Provider<BarberAvailabilityRepository>(create: (_) => CloudBarberAvailabilityService()),
        Provider<ShopClosureRepository>(create: (_) => CloudShopClosureService()),
        Provider<RatingRepository>(create: (_) => CloudRatingService()),
        ProxyProvider<StorageRepository, ProductRepository>(
          update: (_, storage, _) => FirestoreProductService(storage: storage),
        ),
        ProxyProvider<StorageRepository, CommentRepository>(
          update: (_, storage, _) => CloudCommentService(storage: storage),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              AuthController(authService: context.read<AuthRepository>(), userService: context.read<UserRepository>()),
        ),
        ChangeNotifierProvider(create: (context) => UserController(userService: context.read<UserRepository>())),
      ],
      child: MaterialApp(
        title: 'BarberFlow',
        theme: AppTheme.light,
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
