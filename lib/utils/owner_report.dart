import '../models/appointment.dart';

/// Actividad de un barbero en el periodo del informe.
class BarberActivity {
  final String barberId;
  final String barberName;

  /// Citas completadas.
  final int completed;

  /// Citas canceladas o rechazadas.
  final int lost;

  /// Ingresos de las citas completadas y pagadas.
  final double revenue;

  const BarberActivity({
    required this.barberId,
    required this.barberName,
    required this.completed,
    required this.lost,
    required this.revenue,
  });
}

/// Resumen de actividad de las barberías de un dueño.
class OwnerReport {
  final int completed;
  final int lost;
  final int upcoming;

  /// Clientes distintos con al menos una cita completada.
  final int clientsServed;

  /// Suma de las citas completadas y pagadas (el monto de cada cita es
  /// exactamente el precio del servicio, lo impone firestore.rules).
  final double revenue;

  /// Más ocupado primero.
  final List<BarberActivity> byBarber;

  const OwnerReport({
    required this.completed,
    required this.lost,
    required this.upcoming,
    required this.clientsServed,
    required this.revenue,
    required this.byBarber,
  });

  bool get isEmpty => completed == 0 && lost == 0 && upcoming == 0;
}

/// Calcula el informe con las citas cuya fecha cae en `[from, now]` (las
/// próximas se cuentan aparte, desde [now] en adelante). Las citas
/// pendientes o aceptadas que ya pasaron sin completarse no cuentan como
/// atendidas ni como perdidas.
OwnerReport buildOwnerReport(
  Iterable<Appointment> appointments, {
  required DateTime from,
  required DateTime now,
}) {
  var completed = 0;
  var lost = 0;
  var upcoming = 0;
  var revenue = 0.0;
  final clients = <String>{};
  final byBarber = <String, _Tally>{};

  for (final a in appointments) {
    final inPeriod = !a.date.isBefore(from) && !a.date.isAfter(now);
    if (!inPeriod) {
      if (a.date.isAfter(now) &&
          (a.status == AppointmentStatus.accepted ||
              a.status == AppointmentStatus.postponed)) {
        upcoming++;
      }
      continue;
    }
    final tally = byBarber.putIfAbsent(a.barberId, () => _Tally(a.barberName));
    switch (a.status) {
      case AppointmentStatus.completed:
        completed++;
        tally.completed++;
        clients.add(a.clientId);
        if (a.paid) {
          revenue += a.servicePrice;
          tally.revenue += a.servicePrice;
        }
      case AppointmentStatus.cancelled || AppointmentStatus.rejected:
        lost++;
        tally.lost++;
      case AppointmentStatus.pending ||
          AppointmentStatus.accepted ||
          AppointmentStatus.postponed:
        break;
    }
  }

  final rows = [
    for (final entry in byBarber.entries)
      BarberActivity(
        barberId: entry.key,
        barberName: entry.value.name,
        completed: entry.value.completed,
        lost: entry.value.lost,
        revenue: entry.value.revenue,
      ),
  ]..sort((a, b) => b.completed.compareTo(a.completed));

  return OwnerReport(
    completed: completed,
    lost: lost,
    upcoming: upcoming,
    clientsServed: clients.length,
    revenue: revenue,
    byBarber: rows,
  );
}

class _Tally {
  final String name;
  int completed = 0;
  int lost = 0;
  double revenue = 0;

  _Tally(this.name);
}
