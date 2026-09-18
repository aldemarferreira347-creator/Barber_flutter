import { HttpsError } from 'firebase-functions/v2/https';

import { createRefundPurchaseItemsHandler } from '../../src/triggers/https/refundPurchaseItems';
import { PurchaseService } from '../../src/products/purchaseService';

const getMock = jest.fn();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => ({ doc: () => ({ get: getMock }) }),
}));

function fakeService(): jest.Mocked<Pick<PurchaseService, 'refundItems'>> {
  return { refundItems: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createRefundPurchaseItemsHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('refundPurchaseItems callable', () => {
  beforeEach(() => getMock.mockReset());

  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createRefundPurchaseItemsHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, undefined, { purchaseId: 'p1', itemIndexes: [0] })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza si quien llama no es admin', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'owner' }) });
    const service = fakeService();
    const handler = createRefundPurchaseItemsHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, 'owner1', { purchaseId: 'p1', itemIndexes: [0] })).rejects.toMatchObject({ code: 'permission-denied' });
    expect(service.refundItems).not.toHaveBeenCalled();
  });

  it('rechaza itemIndexes que no es un arreglo de números', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    const service = fakeService();
    const handler = createRefundPurchaseItemsHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, 'admin1', { purchaseId: 'p1', itemIndexes: ['a'] })).rejects.toMatchObject({ code: 'invalid-argument' });
  });

  it('delega en el servicio cuando el admin envía un payload válido', async () => {
    getMock.mockResolvedValue({ data: () => ({ role: 'admin' }) });
    const service = fakeService();
    const handler = createRefundPurchaseItemsHandler(service as unknown as PurchaseService);

    const result = await callAs(handler, 'admin1', { purchaseId: 'p1', itemIndexes: [0, 2] });

    expect(result).toEqual({ ok: true });
    expect(service.refundItems).toHaveBeenCalledWith('p1', [0, 2]);
  });
});
