import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/notification_tone.dart';
import '../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_user_service.dart';
import '../services/push_notification_service.dart';

export '../repositories/auth_repository.dart'
    show PhoneCodeHandle, GoogleSignInOutcome, GoogleSignInSuccess, GoogleSignInRequiresPasswordLink, GoogleSignInCancelled;

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Controlador de sesión: expone el estado de auth + el perfil/rol cargado
/// desde Firestore para que las vistas decidan a dónde navegar. Depende de
/// las abstracciones (AuthRepository/UserRepository), no de Firebase
/// directamente, para poder sustituirlas en tests o cambiar de backend.
class AuthController extends ChangeNotifier {
  final AuthRepository _authService;
  final UserRepository _userService;
  final PushNotificationService _pushService;

  AuthController({
    AuthRepository? authService,
    UserRepository? userService,
    PushNotificationService? pushService,
  })  : _authService = authService ?? FirebaseAuthService(),
        _userService = userService ?? FirestoreUserService(),
        _pushService = pushService ?? PushNotificationService() {
    _authSubscription = _authService.authStateChanges.listen(_onAuthChanged);
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  AuthStatus status = AuthStatus.unknown;
  AppUser? profile;
  String? errorMessage;
  bool isBusy = false;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      status = AuthStatus.unauthenticated;
      profile = null;
      notifyListeners();
      return;
    }
    profile = await _userService.fetchUserProfile(user.uid);
    status = AuthStatus.authenticated;
    notifyListeners();
    _registerPushToken(user.uid);
  }

  /// Guarda el token FCM del dispositivo y lo mantiene al día mientras dure
  /// la sesión. Nunca debe poder tumbar el login: si el dispositivo no
  /// soporta push, o el usuario niega el permiso, o falla por cualquier
  /// motivo, se ignora en silencio (push es una mejora, no un requisito).
  void _registerPushToken(String uid) {
    _pushService.requestPermissionAndGetToken().then((token) {
      if (token != null) _userService.addFcmToken(uid, token);
    }).catchError((_) {});

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _pushService.onTokenRefresh.listen(
      (token) => _userService.addFcmToken(uid, token),
      onError: (_) {},
    );
  }

  Future<bool> signIn({required String email, required String password}) {
    return _runGuarded(() async {
      await _authService.signIn(email: email, password: password);
    });
  }

  Future<bool> sendPasswordResetEmail(String email) {
    return _runGuarded(() => _authService.sendPasswordResetEmail(email));
  }

  /// Intenta iniciar sesión con Google. Si ese correo ya tiene una cuenta de
  /// correo/contraseña sin vincular, devuelve [GoogleSignInRequiresPasswordLink]
  /// en vez de completar el login — la UI debe pedir esa contraseña y
  /// llamar a [confirmGoogleLinkWithPassword] (spec 5.1). Null indica un
  /// error real (ver [errorMessage]); [GoogleSignInCancelled] es un caso
  /// normal, no un error.
  Future<GoogleSignInOutcome?> signInWithGoogle() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final outcome = await _authService.signInWithGoogle();
      if (outcome is GoogleSignInSuccess) {
        await _ensureClientProfile(outcome.credential.user!);
      }
      return outcome;
    } on FirebaseException catch (e) {
      errorMessage = e.message ?? 'Error de autenticación';
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Segundo paso del vínculo Google + correo/contraseña: confirma la
  /// contraseña original y completa el login con ambos métodos vinculados.
  Future<bool> confirmGoogleLinkWithPassword({
    required String email,
    required String password,
    required AuthCredential pendingGoogleCredential,
  }) {
    return _runGuarded(() async {
      final credential = await _authService.linkGoogleWithPassword(
        email: email,
        password: password,
        pendingGoogleCredential: pendingGoogleCredential,
      );
      await _ensureClientProfile(credential.user!);
    });
  }

  /// Paso 1 del login por teléfono: envía el código SMS. Devuelve el handle
  /// para confirmarlo, o null si falló (ver [errorMessage]).
  Future<PhoneCodeHandle?> startPhoneVerification(String phoneNumber) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _authService.startPhoneVerification(phoneNumber);
    } on FirebaseException catch (e) {
      errorMessage = e.message ?? 'No se pudo enviar el código';
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Paso 2: confirma el código SMS recibido y completa el inicio de sesión.
  Future<bool> confirmPhoneCode(PhoneCodeHandle handle, String smsCode) {
    return _runGuarded(() async {
      final credential = await handle.confirmCode(smsCode);
      final user = credential.user;
      if (user == null) throw Exception('No se pudo verificar el código');
      await _ensureClientProfile(user);
    });
  }

  /// Crea el perfil Cliente en Firestore si es la primera vez que este uid
  /// inicia sesión (Google/teléfono), o carga el existente. Compartido por
  /// ambos métodos de login social para no duplicar la lógica.
  Future<void> _ensureClientProfile(User user) async {
    final existing = await _userService.fetchUserProfile(user.uid);
    if (existing == null) {
      final newUser = AppUser(
        uid: user.uid,
        email: (user.email ?? '').toLowerCase(),
        name: user.displayName ?? '',
        phone: user.phoneNumber,
        role: UserRole.client,
      );
      await _userService.createUserProfile(newUser);
      profile = newUser;
    } else {
      profile = existing;
    }
  }

  /// Autorregistro público: siempre crea un Cliente. Dueño se obtiene
  /// pagando la suscripción (fase futura de pagos con Nequi) y Barbero lo
  /// crea su Dueño; Admin no se autorregistra nunca. No hay parámetro de rol
  /// a propósito, para que no exista forma de pedir otro rol desde aquí
  /// (defensa en profundidad: lo mismo se exige en firestore.rules).
  Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) {
    return _runGuarded(() async {
      final normalizedEmail = email.trim().toLowerCase();
      final credential = await _authService.register(email: normalizedEmail, password: password);
      final user = credential.user!;
      try {
        final newUser = AppUser(uid: user.uid, email: normalizedEmail, name: name, role: UserRole.client);
        await _userService.createUserProfile(newUser);
      } catch (_) {
        // Si falla la escritura en Firestore, no dejamos una cuenta de Auth
        // huérfana sin perfil: ese correo quedaría bloqueado para siempre
        // ("email already in use") sin ninguna forma de completar el
        // registro. La borramos y dejamos que el usuario reintente.
        await user.delete();
        rethrow;
      }
      // Cerramos la sesión recién creada a propósito: la pantalla de éxito
      // pide explícitamente iniciar sesión, y así evitamos que el usuario
      // quede autenticado con un perfil que la UI todavía no confirmó.
      await _authService.signOut();
    });
  }

  /// Elige o cambia el tono de notificaciones del usuario actual (spec 3.5).
  Future<bool> chooseNotificationTone(NotificationTone tone) {
    return _runGuarded(() async {
      final current = profile;
      if (current == null) throw Exception('No hay una sesión activa');
      await _userService.setNotificationTone(current.uid, tone);
      profile = current.copyWith(notificationTone: tone);
    });
  }

  Future<void> signOut() => _authService.signOut();

  Future<bool> _runGuarded(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FirebaseException catch (e) {
      errorMessage = e.message ?? 'Error de autenticación';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
