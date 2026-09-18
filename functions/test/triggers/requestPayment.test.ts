import { HttpsError } from 'firebase-functions/v2/https';

import { createRequestPaymentHandler } from '../../src/triggers/https/requestPayment';
import { PaymentGatewayAdapter } from '../../src/payments/types';

function fakeGateway(): jest.Mocked<PaymentGatewayAdapter> {
  return {
    requestPayment: jest.fn().mockResolvedValue('payment1'),
    refund: jest.fn().mockResolvedValue(undefined),
  };
}

function callAs(handler: ReturnType<typeof createRequestPaymentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('requestPayment callable', () => {
  it('rechaza si no hay sesión', async () => {
    const gateway = fakeGateway();
    const handler = createRequestPaymentHandler(gateway);
    await expect(callAs(handler, undefined, { amount: 100, category: 'appointment', relatedId: 'x' })).rejects.toBeInstanceOf(HttpsError);
    expect(gateway.requestPayment).not.toHaveBeenCalled();
  });

  it.each([
    ['amount inválido (cero)', { amount: 0, category: 'appointment', relatedId: 'x' }],
    ['amount negativo', { amount: -5, category: 'appointment', relatedId: 'x' }],
    ['amount no numérico', { amount: 'free', category: 'appointment', relatedId: 'x' }],
    ['category inválida', { amount: 100, category: 'crypto', relatedId: 'x' }],
    ['relatedId vacío', { amount: 100, category: 'appointment', relatedId: '' }],
    ['description muy larga', { amount: 100, category: 'appointment', relatedId: 'x', description: 'a'.repeat(301) }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const gateway = fakeGateway();
    const handler = createRequestPaymentHandler(gateway);
    await expect(callAs(handler, 'user1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(gateway.requestPayment).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como payerId, nunca uno enviado por el cliente', async () => {
    const gateway = fakeGateway();
    const handler = createRequestPaymentHandler(gateway);

    const result = await callAs(handler, 'realUser', {
      amount: 20000,
      category: 'appointment',
      relatedId: 'appt1',
      payerId: 'someone-else',
    });

    expect(result).toEqual({ id: 'payment1' });
    expect(gateway.requestPayment).toHaveBeenCalledWith(
      expect.objectContaining({ payerId: 'realUser', amount: 20000, category: 'appointment', relatedId: 'appt1' }),
    );
  });
});
