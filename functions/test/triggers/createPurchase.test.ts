import { HttpsError } from 'firebase-functions/v2/https';

import { createCreatePurchaseHandler } from '../../src/triggers/https/createPurchase';
import { PurchaseService } from '../../src/products/purchaseService';

function fakeService(): jest.Mocked<Pick<PurchaseService, 'createPurchase'>> {
  return { createPurchase: jest.fn().mockResolvedValue('purchase1') };
}

function callAs(handler: ReturnType<typeof createCreatePurchaseHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('createPurchase callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createCreatePurchaseHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, undefined, { barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 1 }] })).rejects.toBeInstanceOf(
      HttpsError,
    );
    expect(service.createPurchase).not.toHaveBeenCalled();
  });

  it.each([
    ['sin barbershopId', { items: [{ productId: 'p1', quantity: 1 }] }],
    ['sin items', { barbershopId: 'shop1', items: [] }],
    ['demasiados items', { barbershopId: 'shop1', items: Array.from({ length: 21 }, () => ({ productId: 'p1', quantity: 1 })) }],
    ['item sin productId', { barbershopId: 'shop1', items: [{ quantity: 1 }] }],
    ['cantidad no entera', { barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 1.5 }] }],
    ['cantidad negativa', { barbershopId: 'shop1', items: [{ productId: 'p1', quantity: -1 }] }],
    ['appointmentId inválido', { barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 1 }], appointmentId: '' }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createCreatePurchaseHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, 'buyer1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.createPurchase).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como buyerId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createCreatePurchaseHandler(service as unknown as PurchaseService);

    const result = await callAs(handler, 'buyer1', {
      barbershopId: 'shop1',
      items: [{ productId: 'p1', quantity: 2 }],
      buyerId: 'someone-else',
    });

    expect(result).toEqual({ id: 'purchase1' });
    expect(service.createPurchase).toHaveBeenCalledWith({
      barbershopId: 'shop1',
      items: [{ productId: 'p1', quantity: 2 }],
      appointmentId: null,
      buyerId: 'buyer1',
    });
  });
});
