import 'package:barber/models/day_schedule.dart';
import 'package:barber/utils/shop_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // lunes a sábado 09:00–19:00, domingo cerrado.
  final week = {
    for (final day in kWeekdays)
      day: DaySchedule(
        isOpen: day != 'domingo',
        openTime: '09:00',
        closeTime: '19:00',
      ),
  };

  // 2026-10-05 es lunes.
  test('abierta dentro del horario', () {
    final status = shopOpenStatus(week, now: DateTime(2026, 10, 5, 10, 30));
    expect(status.isOpen, isTrue);
    expect(status.label, 'Abierta · cierra 19:00');
  });

  test('antes de abrir: abre hoy', () {
    final status = shopOpenStatus(week, now: DateTime(2026, 10, 5, 7));
    expect(status.isOpen, isFalse);
    expect(status.label, 'Cerrada · abre hoy 09:00');
  });

  test('después de cerrar: abre mañana', () {
    final status = shopOpenStatus(week, now: DateTime(2026, 10, 5, 20));
    expect(status.label, 'Cerrada · abre mañana 09:00');
  });

  test('sábado tarde con domingo cerrado: abre el lunes', () {
    final status = shopOpenStatus(week, now: DateTime(2026, 10, 10, 20));
    expect(status.label, 'Cerrada · abre lun 09:00');
  });

  test('el límite de cierre ya es cerrado', () {
    expect(
      shopOpenStatus(week, now: DateTime(2026, 10, 5, 19)).isOpen,
      isFalse,
    );
  });

  test('horario vacío usa el predeterminado y todo cerrado no revienta', () {
    expect(
      shopOpenStatus(const {}, now: DateTime(2026, 10, 5, 10)).isOpen,
      isTrue,
    );
    final closed = {
      for (final day in kWeekdays) day: const DaySchedule(isOpen: false),
    };
    expect(
      shopOpenStatus(closed, now: DateTime(2026, 10, 5, 10)).label,
      'Cerrada',
    );
  });
}
