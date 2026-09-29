import 'package:barber/models/barbershop.dart';
import 'package:barber/views/barbershop/payment_insight.dart';
import 'package:flutter_test/flutter_test.dart';

Barbershop _shop({
  BarbershopApprovalStatus approval = BarbershopApprovalStatus.approved,
  PaymentStatus payment = PaymentStatus.ok,
  DateTime? due,
}) => Barbershop(
  id: 's1',
  ownerId: 'o1',
  name: 'Central',
  active: true,
  approvalStatus: approval,
  paymentStatus: payment,
  paymentDueDate: due,
);

void main() {
  final now = DateTime(2030, 1, 10);

  test('mensualidad al día con vencimiento lejano: sin alertas', () {
    expect(shopAlerts(_shop(due: DateTime(2030, 2, 1)), now: now), isEmpty);
  });

  test('vence en pocos días: avisa que está por vencer', () {
    final alerts = shopAlerts(_shop(due: DateTime(2030, 1, 12)), now: now);
    expect(alerts.single.title, contains('por vencer'));
  });

  test('en mora: alerta de mensualidad vencida', () {
    final alerts = shopAlerts(
      _shop(payment: PaymentStatus.overdue, due: DateTime(2030, 1, 8)),
      now: now,
    );
    expect(alerts.single.title, 'Mensualidad vencida');
  });

  test('gracia agotada: alerta de bloqueo inminente', () {
    final alerts = shopAlerts(
      _shop(payment: PaymentStatus.overdue, due: DateTime(2029, 12, 1)),
      now: now,
    );
    expect(alerts.single.title, contains('sin pagar'));
  });

  test('bloqueada: alerta de barbería bloqueada', () {
    final alerts = shopAlerts(_shop(payment: PaymentStatus.blocked), now: now);
    expect(alerts.single.title, 'Barbería bloqueada');
  });

  test('pendiente, rechazada y borrador tienen su propia alerta', () {
    for (final status in [
      BarbershopApprovalStatus.pending,
      BarbershopApprovalStatus.rejected,
      BarbershopApprovalStatus.draft,
    ]) {
      expect(shopAlerts(_shop(approval: status), now: now), hasLength(1));
    }
  });
}
