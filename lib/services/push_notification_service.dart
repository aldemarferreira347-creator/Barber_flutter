import 'package:firebase_messaging/firebase_messaging.dart';

/// Wrapper sobre firebase_messaging: sin lógica de persistencia ni de UI.
/// Quien la use decide qué hacer con el token (p.ej. guardarlo en
/// users/{uid}.fcmTokens vía UserRepository) — esta clase no conoce
/// Firestore, solo la capacidad nativa de push.
class PushNotificationService {
  final FirebaseMessaging _messaging;

  PushNotificationService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Pide permiso de notificaciones si hace falta y devuelve el token FCM
  /// del dispositivo, o null si el usuario no dio permiso o la plataforma
  /// actual no soporta push (p.ej. Windows/Linux de escritorio).
  Future<String?> requestPermissionAndGetToken() async {
    final settings = await _messaging.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return null;
    return _messaging.getToken();
  }

  /// El token FCM puede cambiar mientras la sesión sigue activa (p.ej. el
  /// SO lo rota); hay que reflejar el nuevo token en Firestore cuando pase.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
