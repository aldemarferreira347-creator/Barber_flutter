import 'package:firebase_auth/firebase_auth.dart';

/// Handle devuelto tras enviar el código SMS: guarda cómo confirmarlo sin
/// exponer los detalles de verificationId/RecaptchaVerifier a la UI.
class PhoneCodeHandle {
  final Future<UserCredential> Function(String smsCode) confirmCode;

  const PhoneCodeHandle(this.confirmCode);
}

/// Abstracción sobre el proveedor de autenticación. Los controllers
/// dependen de esta interfaz, no de FirebaseAuth directamente (DIP).
abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  User? get currentUser;

  Future<UserCredential> signIn({required String email, required String password});

  Future<UserCredential> register({required String email, required String password});

  Future<void> sendPasswordResetEmail(String email);

  /// Devuelve null si el usuario cancela el selector de cuenta de Google.
  Future<UserCredential?> signInWithGoogle();

  /// Envía el código SMS a [phoneNumber] (formato E.164, ej. +573001234567).
  /// El [PhoneCodeHandle] resultante confirma el código ingresado por el
  /// usuario y completa el inicio de sesión.
  Future<PhoneCodeHandle> startPhoneVerification(String phoneNumber);

  Future<void> signOut();
}
