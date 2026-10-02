/// Etiquetas de fecha y hora en español para la interfaz ("Hoy · 10:00",
/// "Mañana · 16:30", "vie 5 oct · 09:00"). Sin dependencias: la app solo
/// necesita estos formatos cortos.
const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// "10:00" (24 h).
String timeLabel(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Hoy", "Mañana", "Ayer" o "vie 5 oct" (con año si no es el actual).
String dayLabel(DateTime d, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final days = _dayOf(d).difference(today).inDays;
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Mañana';
  if (days == -1) return 'Ayer';
  final base = '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// "Mañana · 10:00".
String dateTimeLabel(DateTime d, {DateTime? now}) =>
    '${dayLabel(d, now: now)} · ${timeLabel(d)}';

/// "03/10/2026 · 10:00" — formato numérico para listas e historial.
String numericDateTimeLabel(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} · ${timeLabel(d)}';

/// Tiempo restante legible: "22 h 10 min", "45 min" o "vencido".
String remainingLabel(DateTime until, {DateTime? now}) {
  final diff = until.difference(now ?? DateTime.now());
  if (diff.isNegative || diff.inMinutes == 0) return 'vencido';
  final hours = diff.inHours;
  final minutes = diff.inMinutes % 60;
  if (hours == 0) return '$minutes min';
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}
