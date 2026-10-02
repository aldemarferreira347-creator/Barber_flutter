import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Conecta la app a los emuladores locales de Firebase (Auth, Firestore y
/// Storage) en lugar del proyecto real. Solo en modo debug y solo si se
/// arranca con `--dart-define=USE_EMULATOR=true`:
///
///     flutter run -d web-server --dart-define=USE_EMULATOR=true
///
/// Los emuladores y los usuarios de prueba por rol se levantan con
/// `npm run emulators` y `npm run seed` dentro de `functions/`.
const bool kUseEmulators = bool.fromEnvironment('USE_EMULATOR');

void connectToEmulatorsIfRequested() {
  if (!kUseEmulators || !kDebugMode) return;
  // En Android el emulador ve el host como 10.0.2.2; en el resto, localhost.
  final host = defaultTargetPlatform == TargetPlatform.android && !kIsWeb
      ? '10.0.2.2'
      : 'localhost';
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
  debugPrint('Firebase: usando emuladores locales en $host');
}
