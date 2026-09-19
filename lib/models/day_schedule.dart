class DaySchedule {
  final bool isOpen;
  final String openTime;
  final String closeTime;

  const DaySchedule({this.isOpen = true, this.openTime = '08:00', this.closeTime = '18:00'});

  factory DaySchedule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DaySchedule();
    return DaySchedule(
      isOpen: map['isOpen'] as bool? ?? true,
      openTime: map['openTime'] as String? ?? '08:00',
      closeTime: map['closeTime'] as String? ?? '18:00',
    );
  }

  Map<String, dynamic> toMap() => {'isOpen': isOpen, 'openTime': openTime, 'closeTime': closeTime};

  DaySchedule copyWith({bool? isOpen, String? openTime, String? closeTime}) {
    return DaySchedule(
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

/// Claves fijas para el horario semanal (lunes..domingo), en el orden en
/// que deben mostrarse.
const List<String> kWeekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

Map<String, DaySchedule> weekScheduleFromMap(Map<String, dynamic>? map) {
  if (map == null) {
    return {for (final day in kWeekdays) day: const DaySchedule()};
  }
  return {for (final day in kWeekdays) day: DaySchedule.fromMap(map[day] as Map<String, dynamic>?)};
}

Map<String, dynamic> weekScheduleToMap(Map<String, DaySchedule> schedule) {
  return {for (final entry in schedule.entries) entry.key: entry.value.toMap()};
}
