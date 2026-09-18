import 'package:firebase_auth/firebase_auth.dart';

/// Handle devuelto tras enviar el código SMS: guarda cómo confirmarlo sin
/// exponer los detalles de verificationId/RecaptchaVerifier a la UI.
class PhoneCodeHandle {
  final Future<UserCredential> Function(String smsCode) confirmCode;

  const PhoneCodeHandle(this.confirmCode);
}

/// Resultado de un intento de inicio de sesión con Google (spec 5.1).
sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();
}

/// Login completado: cuenta nueva, o ya vinculada a Google de antes.
class GoogleSignInSuccess extends GoogleSignInOutcome {
  final UserCredential credential;
  const GoogleSignInSuccess(this.credential);
}

/// Ya existe una cuenta de correo/contraseña con este mismo correo, sin
/// vincular a Google todavía. La UI debe pedir esa contraseña original y
/// llamar a [AuthRepository.linkGoogleWithPassword] antes de completar el
/// login — evita que alguien se apropie de una cuenta ajena solo por
/// coincidir en el correo.
class GoogleSignInRequiresPasswordLink extends GoogleSignInOutcome {
  final String email;
  final AuthCredential pendingGoogleCredential;
  const GoogleSignInRequiresPasswordLink({required this.email, required this.pendingGoogleCredential});
}

/// El usuario cerró el selector de cuenta de Google sin elegir ninguna.
class GoogleSignInCancelled extends GoogleSignInOutcome {
  const GoogleSignInCancelled();
}

/// Abstracción sobre el proveedor de autenticación. Los controllers
/// dependen de esta interfaz, no de FirebaseAuth directamente (DIP).
abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential> signIn({required String email, required String password});

  Future<UserCredential> register({required String email, required String password});

  Future<void> sendPasswordResetEmail(String email);

  Future<GoogleSignInOutcome> signInWithGoogle();

  /// Completa el login de Google confirmando la contraseña de la cuenta de
  /// correo/contraseña existente con ese correo, y vincula ambos métodos a
  /// la misma cuenta (ver [GoogleSignInRequiresPasswordLink]).
  Future<UserCredential> linkGoogleWithPassword({
    required String email,
    required String password,
    required AuthCredential pendingGoogleCredential,
  });

  /// Envía el código SMS a [phoneNumber] (formato E.164, ej. +573001234567).
  /// El [PhoneCodeHandle] resultante confirma el código ingresado por el
  /// usuario y completa el inicio de sesión.
  Future<PhoneCodeHandle> startPhoneVerification(String phoneNumber);

  Future<void> signOut();
}
