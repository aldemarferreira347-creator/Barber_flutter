import { createExpirePurchasesHandler } from '../../../src/triggers/scheduled/expirePurchases';
import { PurchaseService } from '../../../src/products/purchaseService';

function fakeService(count: number): jest.Mocked<Pick<PurchaseService, 'expireOverduePurchases'>> {
  return { expireOverduePurchases: jest.fn().mockResolvedValue(count) };
}

describe('expirePurchases scheduled function', () => {
  it('llama a expireOverduePurchases en cada corrida', async () => {
    const service = fakeService(3);
    const handler = createExpirePurchasesHandler(service as unknown as PurchaseService);

    await handler.run({} as never);

    expect(service.expireOverduePurchases).toHaveBeenCalledTimes(1);
  });

  it('no falla cuando no hay compras vencidas', async () => {
    const service = fakeService(0);
    const handler = createExpirePurchasesHandler(service as unknown as PurchaseService);

    await expect(handler.run({} as never)).resolves.toBeUndefined();
  });
});
