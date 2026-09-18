import { dispatchAppointmentReminder } from '../../src/notifications/dispatchTemplatedNotification';
import { dispatchNotification } from '../../src/notifications/notificationDispatcher';
import * as userDirectory from '../../src/notifications/userDirectory';

jest.mock('../../src/notifications/notificationDispatcher');
jest.mock('../../src/notifications/userDirectory');

const BASE_INPUT = { toUserId: 'user1', kind: '1h' as const, serviceName: 'Corte', barbershopName: 'BarberFlow', time: '15:00' };

describe('dispatchAppointmentReminder', () => {
  beforeEach(() => jest.mocked(dispatchNotification).mockClear());

  it('usa el tono del destinatario para redactar el mensaje', async () => {
    jest.mocked(userDirectory.fetchNotificationRecipient).mockResolvedValue({
      uid: 'user1',
      fcmTokens: [],
      phone: null,
      email: null,
      notificationTone: 'friendly',
    });

    await dispatchAppointmentReminder(BASE_INPUT);

    expect(dispatchNotification).toHaveBeenCalledWith(
      expect.objectContaining({ toUserId: 'user1', category: 'appointment_reminder' }),
    );
    const call = jest.mocked(dispatchNotification).mock.calls[0][0];
    expect(call.body).toContain('Corte');
    expect(call.body).toContain('BarberFlow');
  });

  it('usa tono normal por defecto si el destinatario no existe', async () => {
    jest.mocked(userDirectory.fetchNotificationRecipient).mockResolvedValue(null);

    await dispatchAppointmentReminder(BASE_INPUT);

    expect(dispatchNotification).toHaveBeenCalledTimes(1);
  });

  it('pasa por el mismo dispatchNotification para el recordatorio de 15 minutos', async () => {
    jest.mocked(userDirectory.fetchNotificationRecipient).mockResolvedValue({
      uid: 'user1',
      fcmTokens: [],
      phone: null,
      email: null,
      notificationTone: 'normal',
    });

    await dispatchAppointmentReminder({ ...BASE_INPUT, kind: '15m' });

    expect(dispatchNotification).toHaveBeenCalledWith(expect.objectContaining({ category: 'appointment_reminder' }));
  });
});
