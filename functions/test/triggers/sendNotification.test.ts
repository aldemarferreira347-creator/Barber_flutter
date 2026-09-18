import { HttpsError } from 'firebase-functions/v2/https';

import { dispatchNotification } from '../../src/notifications/notificationDispatcher';
import { sendNotification } from '../../src/triggers/https/sendNotification';

const getMock = jest.fn();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => ({ doc: () => ({ get: getMock }) }),
}));

jest.mock('../../src/notifications/notificationDispatcher');

function callAs(uid: string | undefined, data: Record<string, unknown>) {
  return sendNotification.run({
    data,
    auth: uid ? ({ uid } as never) : undefined,
  } as never);
}

describe('sendNotification callable', () => {
  beforeEach(() => {
    getMock.mockReset();
    jest.mocked(dispatchNotification).mockClear().mockResolvedValue(undefined);
  });

  it('rechaza si no hay sesión', async () => {
    await expect(callAs(undefined, { toUserId: 'u1', title: 't', body: 'b' })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza si quien llama no es admin', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'owner' }) });
    await expect(callAs('caller1', { toUserId: 'u1', title: 't', body: 'b' })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rechaza payload inválido (title vacío)', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    await expect(callAs('admin1', { toUserId: 'u1', title: '', body: 'b' })).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(dispatchNotification).not.toHaveBeenCalled();
  });

  it('despacha la notificación cuando quien llama es admin y el payload es válido', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });

    const result = await callAs('admin1', { toUserId: 'u1', title: ' Hola ', body: ' Cuerpo ' });

    expect(result).toEqual({ ok: true });
    expect(dispatchNotification).toHaveBeenCalledWith({ toUserId: 'u1', title: 'Hola', body: 'Cuerpo', category: 'manual' });
  });
});
