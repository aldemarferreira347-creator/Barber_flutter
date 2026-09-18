import { HttpsError } from 'firebase-functions/v2/https';

import { createPayBarbershopSubscriptionHandler } from '../../src/triggers/https/payBarbershopSubscription';
import { SubscriptionService } from '../../src/barbershops/subscriptionService';

function fakeService(): jest.Mocked<Pick<SubscriptionService, 'paySubscription'>> {
  return { paySubscription: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createPayBarbershopSubscriptionHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('payBarbershopSubscription callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createPayBarbershopSubscriptionHandler(service as unknown as SubscriptionService);
    await expect(callAs(handler, undefined, { barbershopId: 'shop1' })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza sin barbershopId', async () => {
    const service = fakeService();
    const handler = createPayBarbershopSubscriptionHandler(service as unknown as SubscriptionService);
    await expect(callAs(handler, 'owner1', { barbershopId: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.paySubscription).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como requestedBy y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createPayBarbershopSubscriptionHandler(service as unknown as SubscriptionService);

    const result = await callAs(handler, 'owner1', { barbershopId: 'shop1' });

    expect(result).toEqual({ success: true });
    expect(service.paySubscription).toHaveBeenCalledWith({ barbershopId: 'shop1', requestedBy: 'owner1' });
  });
});
