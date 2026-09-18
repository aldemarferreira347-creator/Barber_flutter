import { ShopClosureService } from '../../src/barbershops/shopClosureService';
import { dispatchShopClosureNotice } from '../../src/notifications/dispatchTemplatedNotification';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  Timestamp: class FakeTimestamp {},
}));

jest.mock('../../src/notifications/dispatchTemplatedNotification');

const CLOSED_FROM = new Date('2026-06-01T00:00:00Z');
const CLOSED_UNTIL = new Date('2026-06-01T23:59:59Z');

function baseInput(overrides: Partial<Record<string, unknown>> = {}) {
  return {
    barbershopId: 'shop1',
    closedFrom: CLOSED_FROM,
    closedUntil: CLOSED_UNTIL,
    reason: 'Corte de energía en la zona',
    requestedBy: 'owner1',
    ...overrides,
  };
}

beforeEach(() => {
  fakeFirestore.reset();
  jest.mocked(dispatchShopClosureNotice).mockClear().mockResolvedValue(undefined);
  fakeFirestore.seed('users/owner1', { role: 'owner' });
  fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1', name: 'BarberFlow Centro' });
});

describe('ShopClosureService.closeForExternalEvent', () => {
  it('aplaza las citas pagadas y próximas dentro del rango, con penalización marcada', async () => {
    fakeFirestore.seed('appointments/appt1', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date('2026-06-01T15:00:00Z'),
    });
    await fakeFirestore.doc('appointmentSlots/barber1_2026-06-01T15:00').set({});

    const service = new ShopClosureService();
    const result = await service.closeForExternalEvent(baseInput());

    expect(result.appointmentsAffected).toBe(1);
    const appointment = (await fakeFirestore.doc('appointments/appt1').get()).data()!;
    expect(appointment.status).toBe('postponed');
    expect(appointment.forcedRatingPenalty).toBe(true);
    expect(dispatchShopClosureNotice).toHaveBeenCalledWith({ toUserId: 'client1', barbershopName: 'BarberFlow Centro', serviceName: 'Corte' });
    expect((await fakeFirestore.doc('appointmentSlots/barber1_2026-06-01T15:00').get()).exists).toBe(false);

    const closure = (await fakeFirestore.doc(`shopClosures/${result.closureId}`).get()).data()!;
    expect(closure.appointmentsAffected).toBe(1);
  });

  it('no toca reservas sin pago', async () => {
    fakeFirestore.seed('appointments/appt1', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: false,
      date: new Date('2026-06-01T15:00:00Z'),
    });

    const service = new ShopClosureService();
    const result = await service.closeForExternalEvent(baseInput());

    expect(result.appointmentsAffected).toBe(0);
    expect((await fakeFirestore.doc('appointments/appt1').get()).data()!.status).toBe('accepted');
  });

  it('no toca citas ya canceladas o completadas', async () => {
    fakeFirestore.seed('appointments/appt1', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'completed',
      paid: true,
      date: new Date('2026-06-01T15:00:00Z'),
    });

    const service = new ShopClosureService();
    const result = await service.closeForExternalEvent(baseInput());

    expect(result.appointmentsAffected).toBe(0);
  });

  it('no toca citas de otra barbería ni fuera del rango cerrado', async () => {
    fakeFirestore.seed('appointments/otherShop', {
      barbershopId: 'shop2',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date('2026-06-01T15:00:00Z'),
    });
    fakeFirestore.seed('appointments/outOfRange', {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date('2026-06-05T15:00:00Z'),
    });

    const service = new ShopClosureService();
    const result = await service.closeForExternalEvent(baseInput());

    expect(result.appointmentsAffected).toBe(0);
  });

  it('rechaza un motivo vacío', async () => {
    const service = new ShopClosureService();
    await expect(service.closeForExternalEvent(baseInput({ reason: '   ' }))).rejects.toThrow('motivo');
  });

  it('rechaza un rango inválido (closedUntil <= closedFrom)', async () => {
    const service = new ShopClosureService();
    await expect(service.closeForExternalEvent(baseInput({ closedUntil: CLOSED_FROM }))).rejects.toThrow('posterior');
  });

  it('rechaza a quien no es dueño de esa barbería', async () => {
    fakeFirestore.seed('users/stranger1', { role: 'client' });
    const service = new ShopClosureService();
    await expect(service.closeForExternalEvent(baseInput({ requestedBy: 'stranger1' }))).rejects.toThrow('Solo el dueño');
  });
});
