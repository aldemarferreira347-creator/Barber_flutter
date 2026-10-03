import 'package:barber/models/appointment.dart';
import 'package:barber/utils/owner_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  final weekAgo = now.subtract(const Duration(days: 7));

  Appointment appointment(
    String id,
    DateTime date, {
    String barberId = 'b1',
    String barberName = 'Beto',
    String clientId = 'c1',
    AppointmentStatus status = AppointmentStatus.completed,
    bool paid = true,
    double price = 20000,
  }) => Appointment(
    id: id,
    barbershopId: 's',
    barberId: barberId,
    barberName: barberName,
    clientId: clientId,
    clientName: 'Cliente',
    serviceId: 'svc',
    serviceName: 'Corte',
    servicePrice: price,
    durationMinutes: 30,
    date: date,
    status: status,
    paid: paid,
  );

  test('cuenta atendidas, clientes distintos e ingresos pagados', () {
    final report = buildOwnerReport(
      [
        appointment('1', DateTime(2026, 10, 9, 10)),
        appointment('2', DateTime(2026, 10, 9, 11)),
        appointment('3', DateTime(2026, 10, 8, 10), clientId: 'c2'),
        // Completada pero pagada en la barbería: atendida, sin ingreso.
        appointment('4', DateTime(2026, 10, 8, 11), paid: false),
      ],
      from: weekAgo,
      now: now,
    );

    expect(report.completed, 4);
    expect(report.clientsServed, 2, reason: 'c1 se cuenta una sola vez');
    expect(report.revenue, 60000);
  });

  test('separa canceladas/rechazadas y no cuenta lo que sigue abierto', () {
    final report = buildOwnerReport(
      [
        appointment(
          '1',
          DateTime(2026, 10, 9),
          status: AppointmentStatus.cancelled,
        ),
        appointment(
          '2',
          DateTime(2026, 10, 9),
          status: AppointmentStatus.rejected,
        ),
        // Pasó y nadie la cerró: ni atendida ni perdida.
        appointment(
          '3',
          DateTime(2026, 10, 9),
          status: AppointmentStatus.accepted,
        ),
        appointment(
          '4',
          DateTime(2026, 10, 9),
          status: AppointmentStatus.pending,
        ),
      ],
      from: weekAgo,
      now: now,
    );

    expect(report.lost, 2);
    expect(report.completed, 0);
    expect(report.revenue, 0);
  });

  test('las próximas aceptadas o reprogramadas se cuentan aparte', () {
    final report = buildOwnerReport(
      [
        appointment(
          '1',
          DateTime(2026, 10, 11),
          status: AppointmentStatus.accepted,
        ),
        appointment(
          '2',
          DateTime(2026, 10, 12),
          status: AppointmentStatus.postponed,
        ),
        appointment(
          '3',
          DateTime(2026, 10, 12),
          status: AppointmentStatus.pending,
        ),
      ],
      from: weekAgo,
      now: now,
    );

    expect(report.upcoming, 2);
  });

  test('ignora lo anterior al periodo', () {
    final report = buildOwnerReport(
      [appointment('1', DateTime(2026, 9))],
      from: weekAgo,
      now: now,
    );
    expect(report.isEmpty, isTrue);
    expect(report.byBarber, isEmpty);
  });

  test('reparte por barbero y ordena al más ocupado primero', () {
    final report = buildOwnerReport(
      [
        appointment('1', DateTime(2026, 10, 9)),
        appointment(
          '2',
          DateTime(2026, 10, 9),
          barberId: 'b2',
          barberName: 'Ana',
          price: 30000,
        ),
        appointment(
          '3',
          DateTime(2026, 10, 9),
          barberId: 'b2',
          barberName: 'Ana',
          price: 30000,
        ),
        appointment(
          '4',
          DateTime(2026, 10, 9),
          status: AppointmentStatus.cancelled,
        ),
      ],
      from: weekAgo,
      now: now,
    );

    expect(report.byBarber.map((b) => b.barberName), ['Ana', 'Beto']);
    expect(report.byBarber.first.completed, 2);
    expect(report.byBarber.first.revenue, 60000);
    expect(report.byBarber.last.lost, 1);
  });

  test(
    'el límite del periodo es inclusivo y no cuenta el futuro como hecho',
    () {
      final report = buildOwnerReport(
        [
          appointment('1', weekAgo),
          appointment('2', now.add(const Duration(minutes: 1))),
        ],
        from: weekAgo,
        now: now,
      );
      expect(report.completed, 1);
    },
  );
}
