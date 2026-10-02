import 'package:barber/utils/date_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 2, 9, 30);

  test('hoy, mañana, ayer y fechas lejanas', () {
    expect(dayLabel(DateTime(2026, 10, 2, 23), now: now), 'Hoy');
    expect(dayLabel(DateTime(2026, 10, 3, 0, 5), now: now), 'Mañana');
    expect(dayLabel(DateTime(2026, 10, 1, 23), now: now), 'Ayer');
    expect(dayLabel(DateTime(2026, 10, 9), now: now), 'vie 9 oct');
    expect(dayLabel(DateTime(2027, 1, 4), now: now), 'lun 4 ene 2027');
  });

  test('hora y combinaciones', () {
    expect(timeLabel(DateTime(2026, 1, 1, 7, 5)), '07:05');
    expect(
      dateTimeLabel(DateTime(2026, 10, 3, 16, 30), now: now),
      'Mañana · 16:30',
    );
    expect(
      numericDateTimeLabel(DateTime(2026, 10, 3, 10)),
      '03/10/2026 · 10:00',
    );
  });

  test('tiempo restante', () {
    expect(
      remainingLabel(now.add(const Duration(hours: 22, minutes: 10)), now: now),
      '22 h 10 min',
    );
    expect(remainingLabel(now.add(const Duration(hours: 2)), now: now), '2 h');
    expect(
      remainingLabel(now.add(const Duration(minutes: 45)), now: now),
      '45 min',
    );
    expect(
      remainingLabel(now.subtract(const Duration(minutes: 1)), now: now),
      'vencido',
    );
  });
}
