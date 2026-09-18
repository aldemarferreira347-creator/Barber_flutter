import { createProcessBarbershopBillingHandler } from '../../../src/triggers/scheduled/processBarbershopBilling';
import { SubscriptionService } from '../../../src/barbershops/subscriptionService';

function fakeService(result: { overdue: number; blocked: number }) {
  return { processBilling: jest.fn().mockResolvedValue(result) } as unknown as SubscriptionService;
}

describe('processBarbershopBilling scheduled function', () => {
  it('llama a processBilling en cada corrida', async () => {
    const service = fakeService({ overdue: 1, blocked: 2 });
    const handler = createProcessBarbershopBillingHandler(service);

    await handler.run({} as never);

    expect(service.processBilling).toHaveBeenCalledTimes(1);
  });

  it('no falla cuando no hay barberías vencidas', async () => {
    const service = fakeService({ overdue: 0, blocked: 0 });
    const handler = createProcessBarbershopBillingHandler(service);

    await expect(handler.run({} as never)).resolves.toBeUndefined();
  });
});
