import 'package:firebase_core/firebase_core.dart';

import 'failure.dart';

/// Texto para mostrar al usuario cuando una operación falla. Evita volcar
/// excepciones crudas ("Error: Dart exception: [cloud_firestore/…]") en un
/// aviso: traduce los códigos de Firebase más comunes y quita los prefijos
/// técnicos de las excepciones propias (`Exception('Ese horario ya no…')`).
String errorText(Object error) {
  if (error is LoadTimeoutException) return error.toString();
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
      case 'object-not-found':
        return 'La foto no llegó a subirse. Revisa tu conexión e inténtalo '
            'de nuevo con otra imagen.';
      case 'unauthorized':
        return 'No tienes permiso para subir este archivo. Revisa que tu '
            'sesión y la barbería sigan activas.';
      case 'canceled':
        return 'La subida se canceló. Inténtalo de nuevo.';
      case 'quota-exceeded':
      case 'retry-limit-exceeded':
        return 'No se pudo subir el archivo ahora. Inténtalo más tarde.';
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

/// Mensaje en español para un fallo de inicio de sesión o de registro. Firebase
/// Auth devuelve sus mensajes en inglés ("The supplied auth credential is
/// incorrect..."); aquí se traducen los códigos habituales y, si no se
/// reconoce el código, se usa el mensaje original o [fallback].
String authErrorText(FirebaseException error, {required String fallback}) {
  switch (error.code) {
    case 'wrong-password':
      return 'Contraseña incorrecta.';
    case 'invalid-credential':
    case 'user-not-found':
    case 'invalid-login-credentials':
      return 'Correo o contraseña incorrectos.';
    case 'invalid-email':
      return 'El correo no es válido.';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada. Contacta al administrador.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo.';
    case 'weak-password':
      return 'La contraseña es muy débil: usa al menos 6 caracteres.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión con el servidor. Revisa tu internet e inténtalo '
          'de nuevo.';
    case 'operation-not-allowed':
      return 'Este método de acceso no está habilitado.';
    case 'invalid-verification-code':
      return 'El código no es correcto.';
    case 'invalid-phone-number':
      return 'El número de teléfono no es válido.';
  }
  final message = error.message;
  return message == null || message.isEmpty ? fallback : message;
}
