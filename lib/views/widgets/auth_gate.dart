import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../auth/login_view.dart';
import '../home/admin_home_view.dart';
import '../home/barber_home_view.dart';
import '../home/client_home_view.dart';
import '../home/owner_home_view.dart';
import '../notification/choose_notification_tone_view.dart';

/// Decide qué pantalla mostrar según el estado de sesión y el rol del
/// usuario autenticado, y mantiene el UserController sincronizado con el uid activo.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _watchedUid;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        _watchedUid = null;
        return const LoginView();
      case AuthStatus.authenticated:
        final profile = auth.profile;
        // AuthController solo pasa a `authenticated` DESPUÉS de resolver el
        // fetch del perfil (ver _onAuthChanged) — si sigue null aquí no es
        // "todavía cargando", es que no existe el documento en Firestore
        // para este uid (p.ej. el registro falló a mitad de camino).
        if (profile == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.error_outline, size: 40, color: AppColors.warning),
                    ),
                    const SizedBox(height: 20),
                    const Text('No pudimos cargar tu perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu sesión existe pero no encontramos tus datos. Cierra sesión e intenta iniciar de nuevo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.read<AuthController>().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (profile.uid != _watchedUid) {
          _watchedUid = profile.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<UserController>().watch(profile.uid);
          });
        }

        if (!profile.active) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_outline, size: 40, color: AppColors.error),
                    ),
                    const SizedBox(height: 20),
                    const Text('Cuenta bloqueada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu cuenta o tu barbería fue bloqueada, probablemente por un pago pendiente. Contacta al administrador para resolverlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.read<AuthController>().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (profile.notificationTone == null) {
          return const ChooseNotificationToneView();
        }

        switch (profile.role) {
          case UserRole.admin:
            return const AdminHomeView();
          case UserRole.owner:
            return const OwnerHomeView();
          case UserRole.barber:
            return const BarberHomeView();
          case UserRole.client:
            return const ClientHomeView();
        }
    }
  }
}
