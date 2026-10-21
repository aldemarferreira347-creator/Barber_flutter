import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/notification_tone.dart';
import '../models/user_role.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_user_service.dart';
import '../services/push_notification_service.dart';
import '../utils/shared_stream.dart';
import '../utils/error_text.dart';

export '../repositories/auth_repository.dart'
    show
        PhoneCodeHandle,
        GoogleSignInOutcome,
        GoogleSignInSuccess,
        GoogleSignInRequiresPasswordLink,
        GoogleSignInCancelled;

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Controlador de sesión: expone el estado de auth + el perfil/rol cargado
/// desde Firestore para que las vistas decidan a dónde navegar. Depende de
/// las abstracciones (AuthRepository/UserRepository), no de Firebase
/// directamente, para poder sustituirlas en tests o cambiar de backend.
class AuthController extends ChangeNotifier {
  final AuthRepository _authService;
  final UserRepository _userService;
  final PushNotificationService _pushService;
  String? _fcmToken;

  /// Esperas entre los reintentos de carga del perfil tras iniciar sesión.
  final List<Duration> _profileRetryDelays;

  AuthController({
    AuthRepository? authService,
    UserRepository? userService,
    PushNotificationService? pushService,
    this._profileRetryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 1200),
    ],
  }) : _authService = authService ?? FirebaseAuthService(),
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

  /// El perfil no se pudo leer (red, permisos) aun con sesión iniciada; la
  /// pantalla ofrece reintentar en lugar de quedarse cargando.
  bool profileLoadFailed = false;

  /// Vuelve a cargar el perfil desde Firestore sin pasar por un cambio de
  /// sesión. [profile] solo se refresca normalmente en `_onAuthChanged`
  /// (sign in/out) — cuando algo cambia el perfil del usuario actual en
  /// medio de la sesión (p.ej. auto-promoción a Dueño al registrar una
  /// barbería), hay que pedirlo explícitamente o la UI se queda mostrando
  /// el rol viejo hasta el próximo inicio de sesión.
  Future<void> refreshProfile() async {
    final uid = profile?.uid;
    if (uid == null) return;
    profile = await _userService.fetchUserProfile(uid);
    notifyListeners();
  }

  /// Cuenta los cambios de sesión: una carga de perfil que termina cuando la
  /// sesión ya cambió (cerró sesión, entró otra cuenta) se descarta.
  int _sessionGeneration = 0;

  Future<void> _onAuthChanged(User? user) async {
    final generation = ++_sessionGeneration;
    if (user == null) {
      // Nada de la cuenta anterior debe servirse a la siguiente.
      SharedStreams.resetAll();
      unawaited(_tokenRefreshSubscription?.cancel());
      _tokenRefreshSubscription = null;
      status = AuthStatus.unauthenticated;
      profile = null;
      notifyListeners();
      return;
    }
    final loaded = await _loadProfile(user.uid, generation);
    if (!loaded) return;
    status = AuthStatus.authenticated;
    notifyListeners();
    if (profile != null) _registerPushToken(user.uid);
  }

  /// Lee el perfil con unos reintentos cortos: justo después de iniciar
  /// sesión la primera lectura puede fallar por una red que aún no se
  /// asienta o por el token que todavía no llega a Firestore. Antes, ese
  /// fallo dejaba la app en "cargando" para siempre y el usuario tenía que
  /// iniciar sesión varias veces.
  ///
  /// Devuelve false si la sesión cambió mientras se cargaba: en ese caso no se
  /// toca nada (el perfil de la cuenta anterior jamás se le muestra a la
  /// siguiente).
  Future<bool> _loadProfile(String uid, int generation) async {
    profileLoadFailed = false;
    for (var attempt = 0; ; attempt++) {
      try {
        final loaded = await _userService.fetchUserProfile(uid);
        if (generation != _sessionGeneration) return false;
        profile = loaded;
        return true;
      } catch (error) {
        debugPrint('Perfil no cargado (intento ${attempt + 1}): $error');
        if (attempt >= _profileRetryDelays.length) {
          if (generation != _sessionGeneration) return false;
          profile = null;
          profileLoadFailed = true;
          return true;
        }
        await Future<void>.delayed(_profileRetryDelays[attempt]);
        if (generation != _sessionGeneration) return false;
      }
    }
  }

  /// Reintenta cargar el perfil desde la pantalla de error.
  Future<void> retryProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    isBusy = true;
    notifyListeners();
    await _loadProfile(uid, _sessionGeneration);
    isBusy = false;
    notifyListeners();
    if (profile != null) _registerPushToken(uid);
  }

  /// Guarda el token FCM del dispositivo y lo mantiene al día mientras dure
  /// la sesión. Nunca debe poder tumbar el login: si el dispositivo no
  /// soporta push, o el usuario niega el permiso, o falla por cualquier
  /// motivo, se ignora en silencio (push es una mejora, no un requisito).
  void _registerPushToken(String uid) {
    _pushService
        .requestPermissionAndGetToken()
        .then((token) {
          if (token == null) return;
          _fcmToken = token;
          _userService.addFcmToken(uid, token);
        })
        .catchError((_) {});

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _pushService.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _userService.addFcmToken(uid, token);
    }, onError: (_) {});
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
    } catch (e) {
      // Cualquier otra falla (plugin de Google, Play Services, Credential
      // Manager, etc.) no debe desaparecer en silencio: sin este catch, la
      // vista no recibe outcome ni errorMessage y el botón "Continuar con
      // Google" parece no hacer nada al tocarlo.
      errorMessage = 'No se pudo iniciar sesión con Google: ${errorText(e)}';
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
      errorMessage = authErrorText(e, fallback: 'No se pudo enviar el código');
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
      final credential = await _authService.register(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user!;
      try {
        final newUser = AppUser(
          uid: user.uid,
          email: normalizedEmail,
          name: name,
          role: UserRole.client,
        );
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

  /// Registra un nuevo usuario desde el panel admin sin afectar la sesión
  /// actual del administrador. Usa una instancia secundaria de FirebaseApp
  /// para crear la cuenta de Auth y luego la descarta.
  ///
  /// Devuelve `true` si el registro fue exitoso, `false` si hubo un error
  /// (ver [errorMessage]). El nuevo usuario queda con estado activo y el
  /// [role] elegido por el admin.
  Future<bool> adminRegisterUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    FirebaseApp? tempApp;
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Creamos una segunda instancia de FirebaseApp con las mismas opciones
      // que la principal para poder usar Firebase Auth en paralelo sin
      // cerrar la sesión del admin.
      final options = Firebase.app().options;
      tempApp = await Firebase.initializeApp(
        name: '_admin_register_${DateTime.now().millisecondsSinceEpoch}',
        options: options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final newUid = credential.user!.uid;

      // Perfil en Firestore con el rol elegido por el admin
      final newUser = AppUser(
        uid: newUid,
        email: normalizedEmail,
        name: name.trim(),
        role: role,
      );
      await _userService.createUserProfile(newUser);

      // Cerramos la sesión en la app temporal y la eliminamos
      await tempAuth.signOut();
      return true;
    } on FirebaseException catch (e) {
      errorMessage = authErrorText(e, fallback: 'Error al registrar usuario');
      return false;
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
      isBusy = false;
      notifyListeners();
    }
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

  /// Cierra la sesión. Antes retira el token FCM de este dispositivo del
  /// perfil que se va, para que un teléfono compartido o vendido no siga
  /// asociado a la cuenta anterior. Es de mejor esfuerzo: sin red o con
  /// cualquier error igual se cierra la sesión.
  Future<void> signOut() async {
    final uid = profile?.uid;
    final token = _fcmToken;
    if (uid != null && token != null) {
      try {
        await _userService
            .removeFcmToken(uid, token)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // ignorado a propósito: limpiar el token es opcional.
      }
    }
    _fcmToken = null;
    await _authService.signOut();
  }

  Future<bool> _runGuarded(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FirebaseException catch (e) {
      errorMessage = authErrorText(e, fallback: 'Error de autenticación');
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
