import '../models/day_schedule.dart';

/// Estado de apertura de una barbería a una hora dada, listo para mostrar
/// ("Abierta · cierra 19:00", "Cerrada · abre mañana 09:00").
class ShopOpenStatus {
  final bool isOpen;
  final String label;

  const ShopOpenStatus({required this.isOpen, required this.label});
}

const _shortDays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

int? _minutesOf(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Calcula si la barbería está abierta en [now] según su horario semanal.
/// Un horario vacío se interpreta como el horario por defecto de la app
/// (lo mismo que guarda `Barbershop.toMap`).
ShopOpenStatus shopOpenStatus(
  Map<String, DaySchedule> schedule, {
  DateTime? now,
}) {
  final week = schedule.isEmpty ? weekScheduleFromMap(null) : schedule;
  final current = now ?? DateTime.now();
  final minutesNow = current.hour * 60 + current.minute;

  DaySchedule dayFor(int offset) {
    final weekday = (current.weekday - 1 + offset) % 7;
    return week[kWeekdays[weekday]] ?? const DaySchedule(isOpen: false);
  }

  final today = dayFor(0);
  final open = _minutesOf(today.openTime);
  final close = _minutesOf(today.closeTime);
  if (today.isOpen && open != null && close != null) {
    if (minutesNow >= open && minutesNow < close) {
      return ShopOpenStatus(
        isOpen: true,
        label: 'Abierta · cierra ${today.closeTime}',
      );
    }
    if (minutesNow < open) {
      return ShopOpenStatus(
        isOpen: false,
        label: 'Cerrada · abre hoy ${today.openTime}',
      );
    }
  }

  for (var offset = 1; offset <= 7; offset++) {
    final day = dayFor(offset);
    if (!day.isOpen) continue;
    final when = offset == 1
        ? 'mañana'
        : _shortDays[(current.weekday - 1 + offset) % 7];
    return ShopOpenStatus(
      isOpen: false,
      label: 'Cerrada · abre $when ${day.openTime}',
    );
  }
  return const ShopOpenStatus(isOpen: false, label: 'Cerrada');
}
