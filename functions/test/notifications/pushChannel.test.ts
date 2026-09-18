import { pushChannel } from '../../src/notifications/channels/pushChannel';
import { NotificationRecipient } from '../../src/notifications/types';

const sendEachForMulticastMock = jest.fn();
const updateMock = jest.fn().mockResolvedValue(undefined);

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: sendEachForMulticastMock }),
}));

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => ({ doc: () => ({ update: updateMock }) }),
  FieldValue: { arrayRemove: (...tokens: string[]) => ({ arrayRemove: tokens }) },
}));

const RECIPIENT: NotificationRecipient = {
  uid: 'user1',
  fcmTokens: ['token-valid', 'token-dead'],
  phone: null,
  email: null,
  notificationTone: 'normal',
};

describe('pushChannel', () => {
  beforeEach(() => {
    sendEachForMulticastMock.mockReset();
    updateMock.mockClear();
  });

  it('reporta skipped si el destinatario no tiene tokens registrados', async () => {
    const result = await pushChannel.send({ ...RECIPIENT, fcmTokens: [] }, { title: 't', body: 'b' });
    expect(result).toBe('skipped');
    expect(sendEachForMulticastMock).not.toHaveBeenCalled();
  });

  it('reporta sent si al menos un token recibió el mensaje', async () => {
    sendEachForMulticastMock.mockResolvedValue({
      successCount: 1,
      responses: [{ success: true }, { success: false, error: { code: 'messaging/registration-token-not-registered' } }],
    });

    const result = await pushChannel.send(RECIPIENT, { title: 't', body: 'b' });

    expect(result).toBe('sent');
    expect(updateMock).toHaveBeenCalledWith({ fcmTokens: { arrayRemove: ['token-dead'] } });
  });

  it('reporta skipped si todos los tokens fallan', async () => {
    sendEachForMulticastMock.mockResolvedValue({
      successCount: 0,
      responses: [
        { success: false, error: { code: 'messaging/registration-token-not-registered' } },
        { success: false, error: { code: 'messaging/registration-token-not-registered' } },
      ],
    });

    const result = await pushChannel.send(RECIPIENT, { title: 't', body: 'b' });

    expect(result).toBe('skipped');
    expect(updateMock).toHaveBeenCalledWith({ fcmTokens: { arrayRemove: ['token-valid', 'token-dead'] } });
  });

  it('no limpia tokens cuando el error no indica que están vencidos', async () => {
    sendEachForMulticastMock.mockResolvedValue({
      successCount: 1,
      responses: [{ success: true }, { success: false, error: { code: 'messaging/internal-error' } }],
    });

    await pushChannel.send(RECIPIENT, { title: 't', body: 'b' });

    expect(updateMock).not.toHaveBeenCalled();
  });
});
