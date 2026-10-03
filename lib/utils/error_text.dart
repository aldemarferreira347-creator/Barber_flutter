import 'package:firebase_core/firebase_core.dart';

/// Texto para mostrar al usuario cuando una operación falla. Evita volcar
/// excepciones crudas ("Error: Dart exception: [cloud_firestore/…]") en un
/// aviso: traduce los códigos de Firebase más comunes y quita los prefijos
/// técnicos de las excepciones propias (`Exception('Ese horario ya no…')`).
String errorText(Object error) {
  final code = error is FirebaseException
      ? error.code
      : RegExp(
          r'\[(?:cloud_firestore|firebase_storage|firebase_auth)/([\w-]+)\]',
        ).firstMatch(error.toString())?.group(1);

  if (code != null) {
    switch (code) {
      case 'permission-denied':
        return 'No tienes permiso para hacer esto ahora. Revisa que tu '
            'sesión y la barbería sigan activas.';
      case 'unauthenticated':
        return 'Tu sesión venció. Vuelve a iniciar sesión.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Sin conexión con el servidor. Inténtalo de nuevo.';
      case 'not-found':
        return 'Ya no existe lo que intentas modificar.';
      case 'aborted':
      case 'failed-precondition':
        return 'Algo cambió mientras lo hacías. Inténtalo de nuevo.';
      case 'resource-exhausted':
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    }
    if (error is FirebaseException && (error.message ?? '').isNotEmpty) {
      return error.message!;
    }
    return 'Ocurrió un error inesperado ($code).';
  }

  var text = error.toString();
  for (final prefix in const ['Exception: ', 'Error: ', 'Bad state: ']) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length);
      break;
    }
  }
  text = text.trim();
  return text.isEmpty ? 'Ocurrió un error inesperado.' : text;
}
