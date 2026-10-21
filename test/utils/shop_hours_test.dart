import 'package:barber/models/barbershop.dart';
import 'package:barber/models/day_schedule.dart';
import 'package:barber/models/shop_closure.dart';
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

  group('availableTimeSlots', () {
    // lunes 2026-10-05, abierto 09:00–19:00.
    final monday = DateTime(2026, 10, 5);

    test('genera horas cada 30 min y la última termina al cierre', () {
      final slots = availableTimeSlots(
        week,
        day: monday,
        durationMinutes: 30,
        now: DateTime(2026, 10, 4),
      );
      expect(slots.first, DateTime(2026, 10, 5, 9));
      expect(slots.last, DateTime(2026, 10, 5, 18, 30));
      expect(slots, hasLength(20));
    });

    test(
      'un servicio largo no puede empezar si terminaría después del cierre',
      () {
        final slots = availableTimeSlots(
          week,
          day: monday,
          durationMinutes: 90,
          now: DateTime(2026, 10, 4),
        );
        expect(slots.last, DateTime(2026, 10, 5, 17, 30));
      },
    );

    test('descarta horas pasadas o a menos de 15 min', () {
      final slots = availableTimeSlots(
        week,
        day: monday,
        durationMinutes: 30,
        now: DateTime(2026, 10, 5, 10, 20),
      );
      expect(slots.first, DateTime(2026, 10, 5, 11));
    });

    test('día cerrado o sin lugar: sin horas', () {
      expect(
        availableTimeSlots(
          week,
          day: DateTime(2026, 10, 11),
          durationMinutes: 30,
          now: DateTime(2026, 10, 4),
        ),
        isEmpty,
      );
      expect(
        availableTimeSlots(
          week,
          day: monday,
          durationMinutes: 30,
          now: DateTime(2026, 10, 5, 18, 50),
        ),
        isEmpty,
      );
    });
  });

  group('cierre por evento externo', () {
    final monday = DateTime(2026, 10, 5);
    // Aún no son las 9: todas las horas del día siguen siendo futuras.
    final early = DateTime(2026, 10, 5, 6);

    Barbershop shop(ShopClosure? closure) => Barbershop(
      id: 's',
      name: 'S',
      ownerId: 'o',
      schedule: week,
      closure: closure,
    );

    test('sin cierre se ofrecen todas las horas del horario', () {
      final slots = availableSlotsForShop(
        shop(null),
        day: monday,
        durationMinutes: 30,
        now: early,
      );
      expect(slots.first, DateTime(2026, 10, 5, 9));
      expect(slots.length, 20);
    });

    test('las horas que se cruzan con el cierre desaparecen', () {
      final closure = ShopClosure(
        id: 'c',
        from: DateTime(2026, 10, 5, 12),
        until: DateTime(2026, 10, 5, 14),
        reason: 'Corte de luz',
      );
      final slots = availableSlotsForShop(
        shop(closure),
        day: monday,
        durationMinutes: 30,
        now: early,
      );
      expect(slots, isNot(contains(DateTime(2026, 10, 5, 12))));
      expect(slots, isNot(contains(DateTime(2026, 10, 5, 13, 30))));
      expect(slots, contains(DateTime(2026, 10, 5, 11, 30)));
      expect(slots, contains(DateTime(2026, 10, 5, 14)));
    });

    test('una cita larga que arranca antes pero invade el cierre se quita', () {
      final closure = ShopClosure(
        id: 'c',
        from: DateTime(2026, 10, 5, 12),
        until: DateTime(2026, 10, 5, 14),
        reason: 'x',
      );
      final slots = availableSlotsForShop(
        shop(closure),
        day: monday,
        durationMinutes: 60,
        now: early,
      );
      expect(slots, isNot(contains(DateTime(2026, 10, 5, 11, 30))));
      expect(slots, contains(DateTime(2026, 10, 5, 11)));
    });

    test('sin fecha de regreso no queda ninguna hora desde el inicio', () {
      final closure = ShopClosure(
        id: 'c',
        from: DateTime(2026, 10, 4),
        reason: 'Remodelación',
      );
      expect(
        availableSlotsForShop(
          shop(closure),
          day: DateTime(2026, 10, 12),
          durationMinutes: 30,
          now: early,
        ),
        isEmpty,
      );
    });

    test(
      'shopStatusOf dice cerrada mientras dura y vuelve a la normalidad',
      () {
        final closure = ShopClosure(
          id: 'c',
          from: DateTime(2026, 10, 5, 8),
          until: DateTime(2026, 10, 5, 18),
          reason: 'x',
        );
        final during = shopStatusOf(
          shop(closure),
          now: DateTime(2026, 10, 5, 10),
        );
        expect(during.isOpen, isFalse);
        expect(during.label, startsWith('Cerrada hasta'));
        expect(
          shopStatusOf(
            shop(closure),
            now: DateTime(2026, 10, 5, 18, 30),
          ).isOpen,
          isTrue,
        );
        final indefinite = ShopClosure(
          id: 'c',
          from: DateTime(2026, 10, 5, 8),
          reason: 'x',
        );
        expect(
          shopStatusOf(shop(indefinite), now: DateTime(2026, 10, 9, 10)).label,
          'Cerrada temporalmente',
        );
      },
    );

    test('un cierre cuya fecha ya pasó deja de ser relevante', () {
      final ended = ShopClosure(
        id: 'c',
        from: DateTime(2020, 1, 5),
        until: DateTime(2020, 1, 6),
        reason: 'x',
      );
      expect(shop(ended).relevantClosure(), isNull);
      expect(
        shop(ShopClosure(id: 'c', from: DateTime(2020, 1, 5), reason: 'x'))
            .relevantClosure(),
        isNotNull,
      );
    });
  });
}
