import { dispatchNotification } from '../../src/notifications/notificationDispatcher';
import { NotificationChannel, NotificationRecipient } from '../../src/notifications/types';
import * as userDirectory from '../../src/notifications/userDirectory';

const addMock = jest.fn().mockResolvedValue({ id: 'notif1' });

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => ({ collection: () => ({ add: addMock }) }),
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
}));

jest.mock('../../src/notifications/userDirectory');

const RECIPIENT: NotificationRecipient = {
  uid: 'user1',
  fcmTokens: ['token1'],
  phone: '+573000000000',
  email: 'user1@example.com',
  notificationTone: 'normal',
};

function fakeChannel(name: string, result: 'sent' | 'skipped'): NotificationChannel {
  return { name, send: jest.fn().mockResolvedValue(result) };
}

describe('dispatchNotification', () => {
  beforeEach(() => {
    addMock.mockClear();
    jest.mocked(userDirectory.fetchNotificationRecipient).mockResolvedValue(RECIPIENT);
  });

  it('usa el primer canal que confirma entrega y no prueba los siguientes', async () => {
    const push = fakeChannel('push', 'sent');
    const sms = fakeChannel('sms', 'sent');

    await dispatchNotification(
      { toUserId: 'user1', title: 'Hola', body: 'Cuerpo', category: 'manual' },
      [push, sms],
    );

    expect(push.send).toHaveBeenCalledTimes(1);
    expect(sms.send).not.toHaveBeenCalled();
  });

  it('cae al siguiente canal si el anterior no pudo entregar', async () => {
    const push = fakeChannel('push', 'skipped');
    const sms = fakeChannel('sms', 'skipped');
    const email = fakeChannel('email', 'sent');

    await dispatchNotification(
      { toUserId: 'user1', title: 'Hola', body: 'Cuerpo', category: 'manual' },
      [push, sms, email],
    );

    expect(push.send).toHaveBeenCalledTimes(1);
    expect(sms.send).toHaveBeenCalledTimes(1);
    expect(email.send).toHaveBeenCalledTimes(1);
  });

  it('registra la notificación en Firestore aunque ningún canal logre entregarla', async () => {
    const push = fakeChannel('push', 'skipped');

    await dispatchNotification({ toUserId: 'user1', title: 'Hola', body: 'Cuerpo', category: 'manual' }, [push]);

    expect(addMock).toHaveBeenCalledWith(
      expect.objectContaining({ toUserId: 'user1', title: 'Hola', body: 'Cuerpo', type: 'manual', read: false }),
    );
  });

  it('no escribe ni intenta entregar nada si el destinatario no existe', async () => {
    jest.mocked(userDirectory.fetchNotificationRecipient).mockResolvedValue(null);
    const push = fakeChannel('push', 'sent');

    await dispatchNotification({ toUserId: 'ghost', title: 'Hola', body: 'Cuerpo', category: 'manual' }, [push]);

    expect(addMock).not.toHaveBeenCalled();
    expect(push.send).not.toHaveBeenCalled();
  });
});
