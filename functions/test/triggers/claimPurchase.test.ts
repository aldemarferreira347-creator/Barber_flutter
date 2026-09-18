import { HttpsError } from 'firebase-functions/v2/https';

import { createClaimPurchaseHandler } from '../../src/triggers/https/claimPurchase';
import { PurchaseService } from '../../src/products/purchaseService';

function fakeService(): jest.Mocked<Pick<PurchaseService, 'claimPurchase'>> {
  return { claimPurchase: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createClaimPurchaseHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('claimPurchase callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createClaimPurchaseHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, undefined, { purchaseId: 'p1' })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza purchaseId vacío', async () => {
    const service = fakeService();
    const handler = createClaimPurchaseHandler(service as unknown as PurchaseService);
    await expect(callAs(handler, 'barber1', { purchaseId: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.claimPurchase).not.toHaveBeenCalled();
  });

  it('delega en el servicio con el uid autenticado (la autorización real vive ahí)', async () => {
    const service = fakeService();
    const handler = createClaimPurchaseHandler(service as unknown as PurchaseService);

    const result = await callAs(handler, 'barber1', { purchaseId: 'purchase1' });

    expect(result).toEqual({ ok: true });
    expect(service.claimPurchase).toHaveBeenCalledWith('purchase1', 'barber1');
  });

  it('propaga el error de autorización del servicio', async () => {
    const service = fakeService();
    service.claimPurchase.mockRejectedValue(new HttpsError('permission-denied', 'No tienes permiso sobre esa barbería.'));
    const handler = createClaimPurchaseHandler(service as unknown as PurchaseService);

    await expect(callAs(handler, 'stranger1', { purchaseId: 'purchase1' })).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
