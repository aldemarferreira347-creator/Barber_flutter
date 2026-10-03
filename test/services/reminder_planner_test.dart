import 'package:barber/models/appointment.dart';
import 'package:barber/services/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 5, 8);

  Appointment appointment(
    String id,
    DateTime date, {
    AppointmentStatus status = AppointmentStatus.accepted,
  }) => Appointment(
    id: id,
    barbershopId: 's',
    barberId: 'b',
    barberName: 'Carlos',
    clientId: 'c',
    clientName: 'Juan',
    serviceId: 'svc',
    serviceName: 'Corte clásico',
    servicePrice: 25000,
    durationMinutes: 30,
    date: date,
    status: status,
  );

  test('programa un aviso 1 hora y otro 15 minutos antes', () {
    final reminders = planReminders(
      [appointment('a1', DateTime(2026, 10, 5, 10))],
      audience: ReminderAudience.client,
      now: now,
    );

    expect(reminders.map((r) => r.at), [
      DateTime(2026, 10, 5, 9),
      DateTime(2026, 10, 5, 9, 45),
    ]);
    expect(
      reminders.first.body,
      'Corte clásico con Carlos es en 1 hora (10:00).',
    );
    expect(
      reminders.last.body,
      'Corte clásico con Carlos es en 15 minutos (10:00).',
    );
  });

  test('el barbero ve el nombre del cliente', () {
    final reminders = planReminders(
      [appointment('a1', DateTime(2026, 10, 5, 10))],
      audience: ReminderAudience.barber,
      now: now,
    );
    expect(reminders.first.body, contains('de Juan'));
  });

  test('omite los avisos que ya pasaron, pero conserva el que falta', () {
    // Cita en 40 minutos: la hora antes ya pasó, el de 15 min no.
    final reminders = planReminders(
      [appointment('a1', DateTime(2026, 10, 5, 8, 40))],
      audience: ReminderAudience.client,
      now: now,
    );
    expect(reminders, hasLength(1));
    expect(reminders.single.at, DateTime(2026, 10, 5, 8, 25));
  });

  test('citas pasadas, canceladas, rechazadas, completadas o sin aceptar no avisan', () {
    final future = DateTime(2026, 10, 6, 10);
    final reminders = planReminders(
      [
        appointment('past', DateTime(2026, 10, 4, 10)),
        appointment('cancelled', future, status: AppointmentStatus.cancelled),
        appointment('rejected', future, status: AppointmentStatus.rejected),
        appointment('done', future, status: AppointmentStatus.completed),
        appointment('pending', future, status: AppointmentStatus.pending),
      ],
      audience: ReminderAudience.client,
      now: now,
    );
    expect(reminders, isEmpty);
  });

  test('una cita reprogramada sí avisa', () {
    final reminders = planReminders(
      [
        appointment(
          'moved',
          DateTime(2026, 10, 6, 10),
          status: AppointmentStatus.postponed,
        ),
      ],
      audience: ReminderAudience.client,
      now: now,
    );
    expect(reminders, hasLength(2));
  });

  test('respeta el tope de citas con aviso y empieza por las más próximas', () {
    final many = [
      for (var i = 0; i < kMaxRemindedAppointments + 10; i++)
        appointment('a$i', DateTime(2026, 11).add(Duration(days: i))),
    ];
    final reminders = planReminders(
      many,
      audience: ReminderAudience.client,
      now: now,
    );
    expect(reminders, hasLength(kMaxRemindedAppointments * 2));
    expect(reminders.first.at.isBefore(reminders.last.at), isTrue);
  });

  test('el id es estable y distinto por cita y por anticipación', () {
    const hour = Duration(hours: 1);
    const quarter = Duration(minutes: 15);
    expect(reminderId('a1', hour), reminderId('a1', hour));
    expect(reminderId('a1', hour), isNot(reminderId('a1', quarter)));
    expect(reminderId('a1', hour), isNot(reminderId('a2', hour)));
    expect(reminderId('a1', hour), lessThanOrEqualTo(0x7FFFFFFF));
    expect(reminderId('a1', hour), greaterThanOrEqualTo(0));
  });
}
