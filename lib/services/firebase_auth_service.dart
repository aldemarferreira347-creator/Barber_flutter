import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../repositories/auth_repository.dart';

/// Wrapper delgado sobre FirebaseAuth: sin lógica de UI ni de Firestore.
class FirebaseAuthService implements AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> register({required String email, required String password}) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    await _googleSignIn.initialize();
    final account = await _googleSignIn.authenticate();
    final googleAuth = account.authentication;
    final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    return _auth.signInWithCredential(credential);
  }

  @override
  Future<PhoneCodeHandle> startPhoneVerification(String phoneNumber) async {
    if (kIsWeb) {
      // En web, signInWithPhoneNumber gestiona el reCAPTCHA invisible
      // internamente y devuelve un ConfirmationResult que confirma el SMS.
      final confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
      return PhoneCodeHandle((smsCode) => confirmationResult.confirm(smsCode));
    }

    final completer = Completer<PhoneCodeHandle>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {}, // auto-verificación de Android: el usuario igual confirma el código manualmente
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, resendToken) {
        if (completer.isCompleted) return;
        completer.complete(PhoneCodeHandle((smsCode) {
          final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
          return _auth.signInWithCredential(credential);
        }));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  @override
  Future<void> signOut() async {
    // Primero lo que sí importa: cerrar la sesión de Firebase. El signOut de
    // Google es best-effort — si esta sesión nunca usó Google, el plugin
    // nunca se inicializó y su signOut puede colgarse indefinidamente
    // esperando un canal de plataforma que no existe; no debe bloquear el
    // cierre de sesión real por eso.
    await _auth.signOut();
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {
      // ignorado a propósito: signOut de Google es solo limpieza opcional
    }
  }
}
