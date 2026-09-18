import { BarberAvailabilityService } from '../../src/barbers/barberAvailabilityService';
import { dispatchBarberBack, dispatchRescheduleInvite } from '../../src/notifications/dispatchTemplatedNotification';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  Timestamp: class FakeTimestamp {},
}));

jest.mock('../../src/notifications/dispatchTemplatedNotification');

beforeEach(() => {
  fakeFirestore.reset();
  jest.mocked(dispatchBarberBack).mockClear().mockResolvedValue(undefined);
  jest.mocked(dispatchRescheduleInvite).mockClear().mockResolvedValue(undefined);
});

describe('BarberAvailabilityService.markAway', () => {
  it('guarda awaySince y calcula awayUntilEstimate a partir del estimado del propio barbero', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber' });
    const service = new BarberAvailabilityService();

    await service.markAway('barber1', 30);

    const data = (await fakeFirestore.doc('users/barber1').get()).data()!;
    const awaySince = data.awaySince as Date;
    const awayUntil = data.awayUntilEstimate as Date;
    expect(awayUntil.getTime() - awaySince.getTime()).toBe(30 * 60_000);
  });

  it('rechaza a alguien que no es barbero', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    const service = new BarberAvailabilityService();

    await expect(service.markAway('owner1', 30)).rejects.toThrow('Solo un barbero');
  });
});

describe('BarberAvailabilityService.markReturned', () => {
  it('limpia el estado de ausencia', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awaySince: new Date(), awayUntilEstimate: new Date() });
    const service = new BarberAvailabilityService();

    await service.markReturned('barber1');

    const data = (await fakeFirestore.doc('users/barber1').get()).data()!;
    expect(data.awaySince).toBeNull();
    expect(data.awayUntilEstimate).toBeNull();
  });

  it('avisa que la cita sigue en pie si hay una dentro de la próxima hora', async () => {
    const now = new Date('2026-06-01T14:00:00Z');
    fakeFirestore.seed('users/barber1', { role: 'barber' });
    fakeFirestore.seed('appointments/appt1', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      date: new Date(now.getTime() + 30 * 60_000),
    });
    jest.useFakeTimers().setSystemTime(now);

    const service = new BarberAvailabilityService();
    await service.markReturned('barber1');

    expect(dispatchBarberBack).toHaveBeenCalledWith(expect.objectContaining({ toUserId: 'client1', serviceName: 'Corte' }));
    jest.useRealTimers();
  });

  it('no avisa por una cita a más de una hora, ni por una cancelada dentro de la hora', async () => {
    const now = new Date('2026-06-01T14:00:00Z');
    fakeFirestore.seed('users/barber1', { role: 'barber' });
    fakeFirestore.seed('appointments/far', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      date: new Date(now.getTime() + 120 * 60_000),
    });
    fakeFirestore.seed('appointments/cancelled', {
      barberId: 'barber1',
      clientId: 'client2',
      serviceName: 'Corte',
      status: 'cancelled',
      date: new Date(now.getTime() + 20 * 60_000),
    });
    jest.useFakeTimers().setSystemTime(now);

    const service = new BarberAvailabilityService();
    await service.markReturned('barber1');

    expect(dispatchBarberBack).not.toHaveBeenCalled();
    jest.useRealTimers();
  });

  it('rechaza a alguien que no es barbero', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    const service = new BarberAvailabilityService();

    await expect(service.markReturned('owner1')).rejects.toThrow('Solo un barbero');
  });
});

describe('BarberAvailabilityService.processOverdueBarbers', () => {
  const now = new Date('2026-06-01T14:00:00Z');

  it('aplaza las citas pagadas del resto de hoy de un barbero vencido y libera el horario', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: new Date(now.getTime() - 5 * 60_000) });
    fakeFirestore.seed('appointments/appt1', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date(now.getTime() + 60 * 60_000),
    });
    await fakeFirestore.doc(`appointmentSlots/barber1_${new Date(now.getTime() + 60 * 60_000).toISOString().slice(0, 16)}`).set({});

    const service = new BarberAvailabilityService();
    const result = await service.processOverdueBarbers(now);

    expect(result).toEqual({ barbersAffected: 1, appointmentsPostponed: 1 });
    expect((await fakeFirestore.doc('appointments/appt1').get()).data()!.status).toBe('postponed');
    expect(dispatchRescheduleInvite).toHaveBeenCalledWith({ toUserId: 'client1', serviceName: 'Corte' });
    const slot = await fakeFirestore.doc(`appointmentSlots/barber1_${new Date(now.getTime() + 60 * 60_000).toISOString().slice(0, 16)}`).get();
    expect(slot.exists).toBe(false);
  });

  it('no toca reservas sin pago', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: new Date(now.getTime() - 5 * 60_000) });
    fakeFirestore.seed('appointments/appt1', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: false,
      date: new Date(now.getTime() + 60 * 60_000),
    });

    const service = new BarberAvailabilityService();
    const result = await service.processOverdueBarbers(now);

    expect(result).toEqual({ barbersAffected: 0, appointmentsPostponed: 0 });
    expect((await fakeFirestore.doc('appointments/appt1').get()).data()!.status).toBe('accepted');
  });

  it('ignora citas más allá de hoy', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: new Date(now.getTime() - 5 * 60_000) });
    fakeFirestore.seed('appointments/tomorrow', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date(now.getTime() + 24 * 60 * 60_000),
    });

    const service = new BarberAvailabilityService();
    const result = await service.processOverdueBarbers(now);

    expect(result.appointmentsPostponed).toBe(0);
  });

  it('ignora barberos que no están afuera (awayUntilEstimate null)', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: null });
    fakeFirestore.seed('appointments/appt1', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date(now.getTime() + 60 * 60_000),
    });

    const service = new BarberAvailabilityService();
    const result = await service.processOverdueBarbers(now);

    expect(result).toEqual({ barbersAffected: 0, appointmentsPostponed: 0 });
  });

  it('ignora barberos cuyo estimado todavía no vence', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: new Date(now.getTime() + 30 * 60_000) });
    fakeFirestore.seed('appointments/appt1', {
      barberId: 'barber1',
      clientId: 'client1',
      serviceName: 'Corte',
      status: 'accepted',
      paid: true,
      date: new Date(now.getTime() + 60 * 60_000),
    });

    const service = new BarberAvailabilityService();
    const result = await service.processOverdueBarbers(now);

    expect(result).toEqual({ barbersAffected: 0, appointmentsPostponed: 0 });
  });

  it('limpia awayUntilEstimate del barbero tras procesarlo, para no reprocesarlo en la siguiente corrida', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', awayUntilEstimate: new Date(now.getTime() - 5 * 60_000) });

    const service = new BarberAvailabilityService();
    await service.processOverdueBarbers(now);

    expect((await fakeFirestore.doc('users/barber1').get()).data()!.awayUntilEstimate).toBeNull();
  });
});
