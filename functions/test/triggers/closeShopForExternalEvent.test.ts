import { HttpsError } from 'firebase-functions/v2/https';

import { createCloseShopForExternalEventHandler } from '../../src/triggers/https/closeShopForExternalEvent';
import { ShopClosureService } from '../../src/barbershops/shopClosureService';

function fakeService(): jest.Mocked<Pick<ShopClosureService, 'closeForExternalEvent'>> {
  return { closeForExternalEvent: jest.fn().mockResolvedValue({ closureId: 'closure1', appointmentsAffected: 3 }) };
}

function callAs(handler: ReturnType<typeof createCloseShopForExternalEventHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const VALID_PAYLOAD = {
  barbershopId: 'shop1',
  closedFrom: '2026-06-01T00:00:00.000Z',
  closedUntil: '2026-06-01T23:59:59.000Z',
  reason: 'Corte de energía',
};

describe('closeShopForExternalEvent callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createCloseShopForExternalEventHandler(service as unknown as ShopClosureService);
    await expect(callAs(handler, undefined, VALID_PAYLOAD)).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin barbershopId', { ...VALID_PAYLOAD, barbershopId: '' }],
    ['sin reason', { ...VALID_PAYLOAD, reason: '' }],
    ['reason muy larga', { ...VALID_PAYLOAD, reason: 'a'.repeat(301) }],
    ['closedFrom inválido', { ...VALID_PAYLOAD, closedFrom: 'no-es-fecha' }],
    ['closedUntil inválido', { ...VALID_PAYLOAD, closedUntil: 'no-es-fecha' }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createCloseShopForExternalEventHandler(service as unknown as ShopClosureService);
    await expect(callAs(handler, 'owner1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.closeForExternalEvent).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como requestedBy y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createCloseShopForExternalEventHandler(service as unknown as ShopClosureService);

    const result = await callAs(handler, 'owner1', { ...VALID_PAYLOAD, requestedBy: 'someone-else' });

    expect(result).toEqual({ closureId: 'closure1', appointmentsAffected: 3 });
    expect(service.closeForExternalEvent).toHaveBeenCalledWith(
      expect.objectContaining({ barbershopId: 'shop1', reason: 'Corte de energía', requestedBy: 'owner1' }),
    );
  });
});
