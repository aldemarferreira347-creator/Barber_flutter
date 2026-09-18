import { HttpsError } from 'firebase-functions/v2/https';

import { createRefundPaymentHandler } from '../../src/triggers/https/refundPayment';
import { PaymentGatewayAdapter } from '../../src/payments/types';

const getMock = jest.fn();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => ({ doc: () => ({ get: getMock }) }),
}));

function fakeGateway(): jest.Mocked<PaymentGatewayAdapter> {
  return {
    requestPayment: jest.fn().mockResolvedValue('payment1'),
    refund: jest.fn().mockResolvedValue(undefined),
  };
}

function callAs(handler: ReturnType<typeof createRefundPaymentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('refundPayment callable', () => {
  beforeEach(() => getMock.mockReset());

  it('rechaza si no hay sesión', async () => {
    const gateway = fakeGateway();
    const handler = createRefundPaymentHandler(gateway);
    await expect(callAs(handler, undefined, { paymentId: 'p1' })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza si quien llama no es admin', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'owner' }) });
    const gateway = fakeGateway();
    const handler = createRefundPaymentHandler(gateway);
    await expect(callAs(handler, 'owner1', { paymentId: 'p1' })).rejects.toMatchObject({ code: 'permission-denied' });
    expect(gateway.refund).not.toHaveBeenCalled();
  });

  it('rechaza paymentId vacío', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    const gateway = fakeGateway();
    const handler = createRefundPaymentHandler(gateway);
    await expect(callAs(handler, 'admin1', { paymentId: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('rechaza un amount no positivo cuando se especifica', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    const gateway = fakeGateway();
    const handler = createRefundPaymentHandler(gateway);
    await expect(callAs(handler, 'admin1', { paymentId: 'p1', amount: -1 })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('delega en la pasarela cuando el admin envía un payload válido', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    const gateway = fakeGateway();
    const handler = createRefundPaymentHandler(gateway);

    const result = await callAs(handler, 'admin1', { paymentId: 'p1', amount: 5000 });

    expect(result).toEqual({ ok: true });
    expect(gateway.refund).toHaveBeenCalledWith('p1', 5000);
  });
});
