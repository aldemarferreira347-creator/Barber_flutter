import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_tone.dart';
import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;
  final String? barbershopId;
  final bool active;
  /// Solo aplica a Barbero: si está disponible para recibir citas nuevas
  /// ("darse de baja" temporalmente sin dejar la barbería).
  final bool available;
  final DateTime? createdAt;
  /// Null hasta que el usuario lo elige en su primer inicio de sesión
  /// (ver AuthGate) — a partir de ahí nunca vuelve a ser null.
  final NotificationTone? notificationTone;
  /// Tokens FCM de los dispositivos donde el usuario tiene sesión iniciada
  /// con permiso de notificaciones concedido; puede haber varios (varios
  /// dispositivos a la vez).
  final List<String> fcmTokens;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.barbershopId,
    this.active = true,
    this.available = true,
    this.createdAt,
    this.notificationTone,
    this.fcmTokens = const [],
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      role: UserRoleX.fromValue(map['role'] as String? ?? UserRole.client.value),
      barbershopId: map['barbershopId'] as String?,
      active: map['active'] as bool? ?? true,
      available: map['available'] as bool? ?? true,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      notificationTone: NotificationToneX.fromValue(map['notificationTone'] as String?),
      fcmTokens: (map['fcmTokens'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  AppUser copyWith({NotificationTone? notificationTone}) {
    return AppUser(
      uid: uid,
      email: email,
      name: name,
      role: role,
      phone: phone,
      barbershopId: barbershopId,
      active: active,
      available: available,
      createdAt: createdAt,
      notificationTone: notificationTone ?? this.notificationTone,
      fcmTokens: fcmTokens,
    );
  }

  /// Primer nombre para saludos ("Hola, Carlos"); nunca vacío mientras
  /// [name] tenga algún carácter no-espacio, y '' si [name] está vacío.
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Iniciales para avatares ("Carlos Pérez" → "CP"); '?' si no hay nombre.
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.value,
      'barbershopId': barbershopId,
      'active': active,
      'available': available,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'notificationTone': notificationTone?.value,
      'fcmTokens': fcmTokens,
    };
  }
}
