import '../models/appointment.dart';
import '../utils/date_labels.dart';

/// Quién recibe el recordatorio: cambia a quién se nombra en el texto.
enum ReminderAudience { client, barber }

/// Aviso local programado para un momento exacto.
class PlannedReminder {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
}

/// Cuánto antes de la cita se avisa: 1 hora y 15 minutos (spec 6.6).
const kReminderLeads = [Duration(hours: 1), Duration(minutes: 15)];

/// Máximo de citas con recordatorio. iOS solo permite 64 avisos pendientes;
/// con dos por cita, 30 citas dejan margen.
const kMaxRemindedAppointments = 30;

/// Citas que todavía se van a atender: aceptadas o reprogramadas. Una cita
/// pendiente de aceptar (o de verificar su pago) no se recuerda porque puede
/// no ocurrir.
bool _isActive(Appointment a) =>
    a.status == AppointmentStatus.accepted ||
    a.status == AppointmentStatus.postponed;

/// Id estable (31 bits) por cita y anticipación: FNV-1a sobre el id de la
/// cita y los minutos de anticipación. `String.hashCode` no sirve porque no
/// está garantizado entre ejecuciones.
int reminderId(String appointmentId, Duration lead) {
  var hash = 0x811C9DC5;
  for (final unit in '$appointmentId:${lead.inMinutes}'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// Calcula los recordatorios por programar: dos por cada cita activa
/// futura, omitiendo los que ya pasaron. Las citas más próximas primero y
/// con tope [kMaxRemindedAppointments].
List<PlannedReminder> planReminders(
  Iterable<Appointment> appointments, {
  required ReminderAudience audience,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final upcoming =
      appointments
          .where((a) => _isActive(a) && a.date.isAfter(current))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  final reminders = <PlannedReminder>[];
  for (final appointment in upcoming.take(kMaxRemindedAppointments)) {
    final who = audience == ReminderAudience.client
        ? 'con ${appointment.barberName}'
        : 'de ${appointment.clientName}';
    for (final lead in kReminderLeads) {
      final at = appointment.date.subtract(lead);
      if (!at.isAfter(current)) continue;
      final inLabel = lead.inMinutes >= 60
          ? 'en ${lead.inHours} hora'
          : 'en ${lead.inMinutes} minutos';
      reminders.add(
        PlannedReminder(
          id: reminderId(appointment.id, lead),
          at: at,
          title: 'Recordatorio de cita',
          body:
              '${appointment.serviceName} $who es $inLabel '
              '(${timeLabel(appointment.date)}).',
        ),
      );
    }
  }
  return reminders;
}
