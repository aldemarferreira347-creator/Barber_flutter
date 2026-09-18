import { AppointmentReminderService } from '../../src/appointments/reminderService';
import { dispatchAppointmentReminder } from '../../src/notifications/dispatchTemplatedNotification';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- ver notas en appointmentService.test.ts
  FieldValue: (require('../testUtils/fakeFirestore') as typeof import('../testUtils/fakeFirestore')).createFakeFieldValue(),
  Timestamp: class FakeTimestamp {},
}));

jest.mock('../../src/notifications/dispatchTemplatedNotification');

const NOW = new Date('2026-06-01T14:00:00Z');

function seedAppointment(id: string, overrides: Record<string, unknown> = {}) {
  fakeFirestore.seed(`appointments/${id}`, {
    barbershopId: 'shop1',
    clientId: 'client1',
    serviceName: 'Corte',
    status: 'accepted',
    ...overrides,
  });
}

beforeEach(() => {
  fakeFirestore.reset();
  jest.mocked(dispatchAppointmentReminder).mockClear().mockResolvedValue(undefined);
  fakeFirestore.seed('barbershops/shop1', { name: 'BarberFlow Centro' });
});

describe('AppointmentReminderService.sendDueReminders', () => {
  it('envía el recordatorio de 1h para una cita entre 15 y 60 minutos', async () => {
    seedAppointment('appt1', { date: new Date(NOW.getTime() + 45 * 60_000) });
    const service = new AppointmentReminderService();

    const result = await service.sendDueReminders(NOW);

    expect(result.oneHour).toBe(1);
    expect(dispatchAppointmentReminder).toHaveBeenCalledWith(
      expect.objectContaining({ toUserId: 'client1', kind: '1h', barbershopName: 'BarberFlow Centro' }),
    );
    const stored = (await fakeFirestore.doc('appointments/appt1').get()).data()!;
    expect(stored.reminder1hSentAt).toBeTruthy();
  });

  it('envía el recordatorio de 15min para una cita entre 0 y 15 minutos', async () => {
    seedAppointment('appt1', { date: new Date(NOW.getTime() + 10 * 60_000) });
    const service = new AppointmentReminderService();

    const result = await service.sendDueReminders(NOW);

    expect(result.fifteenMin).toBe(1);
    expect(dispatchAppointmentReminder).toHaveBeenCalledWith(expect.objectContaining({ kind: '15m' }));
  });

  it('no reenvía un recordatorio ya marcado como enviado', async () => {
    seedAppointment('appt1', { date: new Date(NOW.getTime() + 45 * 60_000), reminder1hSentAt: 'already-sent' });
    const service = new AppointmentReminderService();

    const result = await service.sendDueReminders(NOW);

    expect(result.oneHour).toBe(0);
    expect(dispatchAppointmentReminder).not.toHaveBeenCalled();
  });

  it('ignora citas canceladas o rechazadas aunque estén en la ventana', async () => {
    seedAppointment('appt1', { date: new Date(NOW.getTime() + 45 * 60_000), status: 'cancelled' });
    seedAppointment('appt2', { date: new Date(NOW.getTime() + 10 * 60_000), status: 'rejected' });
    const service = new AppointmentReminderService();

    const result = await service.sendDueReminders(NOW);

    expect(result.oneHour + result.fifteenMin).toBe(0);
    expect(dispatchAppointmentReminder).not.toHaveBeenCalled();
  });

  it('ignora citas fuera de la ventana (muy lejos o ya pasadas)', async () => {
    seedAppointment('far', { date: new Date(NOW.getTime() + 120 * 60_000) });
    seedAppointment('past', { date: new Date(NOW.getTime() - 5 * 60_000) });
    const service = new AppointmentReminderService();

    const result = await service.sendDueReminders(NOW);

    expect(result.oneHour + result.fifteenMin).toBe(0);
  });

  it('una cita a 40 minutos puede recibir ambos recordatorios en corridas sucesivas', async () => {
    seedAppointment('appt1', { date: new Date(NOW.getTime() + 40 * 60_000) });
    const service = new AppointmentReminderService();

    const first = await service.sendDueReminders(NOW);
    expect(first.oneHour).toBe(1);
    expect(first.fifteenMin).toBe(0);

    const later = new Date(NOW.getTime() + 30 * 60_000); // ahora quedan 10 min
    const second = await service.sendDueReminders(later);
    expect(second.oneHour).toBe(0);
    expect(second.fifteenMin).toBe(1);
  });
});
