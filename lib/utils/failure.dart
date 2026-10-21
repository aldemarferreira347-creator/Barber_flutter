import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Una consulta tardó demasiado en responder (sin red, o el servidor no
/// contesta). Se trata como falla de conexión: la pantalla ofrece
/// "Reintentar" en lugar de quedarse cargando para siempre.
class LoadTimeoutException implements Exception {
  const LoadTimeoutException();

  @override
  String toString() =>
      'Está tardando más de lo normal. Revisa tu conexión e inténtalo de '
      'nuevo.';
}

/// Familia de una falla de carga o escritura.
enum FailureKind {
  /// Sin red, servidor caído o tiempo agotado: reintentar suele resolverlo.
  network,

  /// `permission-denied` / `unauthenticated`: la sesión o las reglas no
  /// dejan leer esto.
  access,

  /// Falta un índice o la configuración del proyecto (se corrige
  /// desplegando, no reintentando).
  config,

  /// Cualquier otra falla.
  unknown,
}

/// Clasificación de un error de carga o de escritura. Sirve para decidir qué
/// mostrar (¿reintentar?, ¿pedir iniciar sesión?) sin que cada pantalla
/// repita el `switch` sobre códigos de Firebase.
FailureKind classifyFailure(Object error) {
  if (error is LoadTimeoutException || error is TimeoutException) {
    return FailureKind.network;
  }
  final code = failureCode(error);
  switch (code) {
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
    case 'cancelled':
      return FailureKind.network;
    case 'permission-denied':
    case 'unauthenticated':
    case 'unauthorized':
      return FailureKind.access;
    case 'failed-precondition':
      return FailureKind.config;
  }
  return FailureKind.unknown;
}

/// Código de Firebase de [error], también cuando llega envuelto en texto
/// (Flutter web): `[cloud_firestore/permission-denied]`.
String? failureCode(Object error) {
  if (error is FirebaseException) return error.code;
  return RegExp(
    r'\[(?:cloud_firestore|firebase_storage|firebase_auth)/([\w-]+)\]',
  ).firstMatch(error.toString())?.group(1);
}

/// Texto que se registra (no el que ve el usuario) para diagnosticar una
/// consulta que falló: código, mensaje y, si lo trae, el enlace para crear
/// el índice que falta.
String describeFailure(Object error) {
  final code = failureCode(error);
  final message = error is FirebaseException ? error.message : error.toString();
  return '[${code ?? error.runtimeType}] $message';
}
