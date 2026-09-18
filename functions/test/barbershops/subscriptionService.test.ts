import { SubscriptionService } from '../../src/barbershops/subscriptionService';
import { dispatchAppointmentCancelledByBlockNotice, dispatchSubscriptionStatusNotice } from '../../src/notifications/dispatchTemplatedNotification';
import { PaymentGatewayAdapter } from '../../src/payments/types';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  Timestamp: class FakeTimestamp {},
}));

jest.mock('../../src/notifications/dispatchTemplatedNotification');

function fakeGateway(overrides: Partial<PaymentGatewayAdapter> = {}): jest.Mocked<PaymentGatewayAdapter> {
  return {
    requestPayment: jest.fn().mockResolvedValue('payment1'),
    refund: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  } as jest.Mocked<PaymentGatewayAdapter>;
}

beforeEach(() => {
  fakeFirestore.reset();
  jest.mocked(dispatchSubscriptionStatusNotice).mockClear().mockResolvedValue(undefined);
  jest.mocked(dispatchAppointmentCancelledByBlockNotice).mockClear().mockResolvedValue(undefined);
  fakeFirestore.seed('users/owner1', { role: 'owner' });
});

describe('SubscriptionService.paySubscription', () => {
  it('cobra la mensualidad y renueva 30 días, reactivando la barbería', async () => {
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1', name: 'BarberFlow', approvalStatus: 'approved', paymentStatus: 'blocked', active: false });
    const gateway = fakeGateway();
    const service = new SubscriptionService(gateway);

    await service.paySubscription({ barbershopId: 'shop1', requestedBy: 'owner1' });

    expect(gateway.requestPayment).toHaveBeenCalledWith(
      expect.objectContaining({ payerId: 'owner1', category: 'subscription', relatedId: 'shop1' }),
    );
    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('ok');
    expect(shop.active).toBe(true);
    const dueDate = shop.paymentDueDate as Date;
    const daysAhead = (dueDate.getTime() - Date.now()) / (24 * 60 * 60 * 1000);
    expect(daysAhead).toBeGreaterThan(29);
    expect(daysAhead).toBeLessThan(31);
  });

  it('rechaza a quien no es dueño de esa barbería', async () => {
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1', approvalStatus: 'approved' });
    fakeFirestore.seed('users/stranger1', { role: 'client' });
    const service = new SubscriptionService(fakeGateway());
    await expect(service.paySubscription({ barbershopId: 'shop1', requestedBy: 'stranger1' })).rejects.toThrow('Solo el dueño');
  });

  it('rechaza pagar una barbería que todavía no fue aprobada', async () => {
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1', approvalStatus: 'pending' });
    const service = new SubscriptionService(fakeGateway());
    await expect(service.paySubscription({ barbershopId: 'shop1', requestedBy: 'owner1' })).rejects.toThrow('todavía no fue aprobada');
  });
});

describe('SubscriptionService.cancelSubscription', () => {
  const DUE_DATE = new Date('2026-06-15T00:00:00Z');

  beforeEach(() => {
    fakeFirestore.seed('barbershops/shop1', {
      ownerId: 'owner1',
      name: 'BarberFlow',
      approvalStatus: 'approved',
      paymentStatus: 'ok',
      active: true,
      paymentDueDate: DUE_DATE,
    });
  });

  it('bloquea de inmediato, sin período de gracia', async () => {
    const service = new SubscriptionService(fakeGateway());
    await service.cancelSubscription({ barbershopId: 'shop1', requestedBy: 'owner1' });

    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('blocked');
    expect(shop.active).toBe(false);
    expect(dispatchSubscriptionStatusNotice).toHaveBeenCalledWith(
      expect.objectContaining({ toUserId: 'owner1', kind: 'blocked' }),
    );
  });

  it('no toca reservas dentro del período ya pagado, cancela y reembolsa las que caen después (spec 12.6)', async () => {
    fakeFirestore.seed('appointments/withinPeriod', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      paymentId: 'payment1',
      date: new Date('2026-06-10T15:00:00Z'), // antes del corte: no se toca
    });
    fakeFirestore.seed('appointments/trapped', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client2',
      serviceName: 'Barba',
      status: 'pending',
      paid: true,
      paymentId: 'payment2',
      date: new Date('2026-06-20T15:00:00Z'), // después del corte: se cancela y reembolsa
    });
    await fakeFirestore.doc('appointmentSlots/barber1_2026-06-20T15:00').set({});
    const gateway = fakeGateway();
    const service = new SubscriptionService(gateway);

    await service.cancelSubscription({ barbershopId: 'shop1', requestedBy: 'owner1' });

    const untouched = (await fakeFirestore.doc('appointments/withinPeriod').get()).data()!;
    expect(untouched.status).toBe('accepted');

    const trapped = (await fakeFirestore.doc('appointments/trapped').get()).data()!;
    expect(trapped.status).toBe('cancelled');
    expect(gateway.refund).toHaveBeenCalledWith('payment2');
    expect((await fakeFirestore.doc('appointmentSlots/barber1_2026-06-20T15:00').get()).exists).toBe(false);
    expect(dispatchAppointmentCancelledByBlockNotice).toHaveBeenCalledWith(
      expect.objectContaining({ toUserId: 'client2', serviceName: 'Barba' }),
    );
  });

  it('no toca reservas sin pago ni ya canceladas/completadas', async () => {
    fakeFirestore.seed('appointments/unpaid', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'pending',
      paid: false,
      date: new Date('2026-06-25T15:00:00Z'),
    });
    const gateway = fakeGateway();
    const service = new SubscriptionService(gateway);

    await service.cancelSubscription({ barbershopId: 'shop1', requestedBy: 'owner1' });

    expect(gateway.refund).not.toHaveBeenCalled();
    const untouched = (await fakeFirestore.doc('appointments/unpaid').get()).data()!;
    expect(untouched.status).toBe('pending');
  });
});

describe('SubscriptionService.processBilling', () => {
  it('marca overdue las barberías al día cuyo vencimiento ya pasó', async () => {
    fakeFirestore.seed('barbershops/shop1', {
      ownerId: 'owner1',
      name: 'BarberFlow',
      paymentStatus: 'ok',
      paymentDueDate: new Date('2026-06-01T00:00:00Z'),
    });
    const service = new SubscriptionService(fakeGateway());

    const result = await service.processBilling(new Date('2026-06-02T00:00:00Z'));

    expect(result.overdue).toBe(1);
    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('overdue');
    expect(dispatchSubscriptionStatusNotice).toHaveBeenCalledWith(expect.objectContaining({ toUserId: 'owner1', kind: 'overdue' }));
  });

  it('no toca una barbería al día que todavía no vence', async () => {
    fakeFirestore.seed('barbershops/shop1', {
      ownerId: 'owner1',
      paymentStatus: 'ok',
      paymentDueDate: new Date('2026-06-10T00:00:00Z'),
    });
    const service = new SubscriptionService(fakeGateway());

    const result = await service.processBilling(new Date('2026-06-02T00:00:00Z'));

    expect(result.overdue).toBe(0);
    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('ok');
  });

  it('bloquea las barberías overdue cuyo período de gracia ya venció', async () => {
    fakeFirestore.seed('barbershops/shop1', {
      ownerId: 'owner1',
      name: 'BarberFlow',
      paymentStatus: 'overdue',
      paymentDueDate: new Date('2026-06-01T00:00:00Z'),
      active: true,
    });
    // 5 días después del vencimiento: ya pasó el período de gracia (3-5 días).
    const service = new SubscriptionService(fakeGateway());

    const result = await service.processBilling(new Date('2026-06-06T00:00:00Z'));

    expect(result.blocked).toBe(1);
    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('blocked');
    expect(shop.active).toBe(false);
  });

  it('no bloquea una barbería overdue que todavía está dentro del período de gracia', async () => {
    fakeFirestore.seed('barbershops/shop1', {
      ownerId: 'owner1',
      paymentStatus: 'overdue',
      paymentDueDate: new Date('2026-06-01T00:00:00Z'),
      active: true,
    });
    const service = new SubscriptionService(fakeGateway());

    const result = await service.processBilling(new Date('2026-06-02T12:00:00Z'));

    expect(result.blocked).toBe(0);
    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.paymentStatus).toBe('overdue');
    expect(shop.active).toBe(true);
  });
});
