import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/appointment.dart';
import 'reminder_planner.dart';

/// Programa los recordatorios locales de las citas (1 h y 15 min antes).
/// Funciona sin servidor: el sistema operativo dispara los avisos aunque la
/// app esté cerrada. Cada [sync] deja programado exactamente lo que
/// corresponde a las citas recibidas (cancela lo anterior), así una cita
/// cancelada o movida nunca deja un aviso viejo.
abstract class ReminderScheduler {
  Future<void> sync(
    List<Appointment> appointments, {
    required ReminderAudience audience,
  });

  /// Quita todos los recordatorios (al cerrar sesión).
  Future<void> clear();
}

/// Sin efecto: web, escritorio y pruebas.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> sync(
    List<Appointment> appointments, {
    required ReminderAudience audience,
  }) async {}

  @override
  Future<void> clear() async {}
}

/// Recordatorios con `flutter_local_notifications` (Android e iOS).
class LocalReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'appointment_reminders',
    'Recordatorios de citas',
    channelDescription: 'Avisos 1 hora y 15 minutos antes de tu cita',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Inicializa el plugin y pide permiso una sola vez. Devuelve false si el
  /// usuario no autorizó los avisos.
  Future<bool> _ensureReady() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  @override
  Future<void> sync(
    List<Appointment> appointments, {
    required ReminderAudience audience,
  }) async {
    try {
      final reminders = planReminders(appointments, audience: audience);
      if (!await _ensureReady()) return;
      await _plugin.cancelAll();
      for (final reminder in reminders) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          // Solo importa el instante: no depende de la zona horaria local.
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(),
          ),
          // Aviso aproximado (puede adelantarse o retrasarse unos minutos):
          // evita pedir el permiso de alarmas exactas.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      // Un recordatorio que falla nunca debe romper la pantalla.
      debugPrint('No se pudieron programar los recordatorios: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await _ensureReady()) await _plugin.cancelAll();
    } catch (e) {
      debugPrint('No se pudieron quitar los recordatorios: $e');
    }
  }
}

/// El programador adecuado para la plataforma actual.
ReminderScheduler createReminderScheduler() {
  final supported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  return supported ? LocalReminderScheduler() : const NoopReminderScheduler();
}
