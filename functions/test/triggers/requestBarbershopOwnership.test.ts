import { HttpsError } from 'firebase-functions/v2/https';

import { createRequestBarbershopOwnershipHandler } from '../../src/triggers/https/requestBarbershopOwnership';
import { OwnershipService } from '../../src/barbershops/ownershipService';

function fakeService(): jest.Mocked<Pick<OwnershipService, 'requestOwnership'>> {
  return { requestOwnership: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createRequestBarbershopOwnershipHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('requestBarbershopOwnership callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createRequestBarbershopOwnershipHandler(service as unknown as OwnershipService);
    await expect(callAs(handler, undefined, { barbershopId: 'shop1' })).rejects.toBeInstanceOf(HttpsError);
  });

  it('rechaza sin barbershopId', async () => {
    const service = fakeService();
    const handler = createRequestBarbershopOwnershipHandler(service as unknown as OwnershipService);
    await expect(callAs(handler, 'client1', { barbershopId: '' })).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.requestOwnership).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como requestedBy y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createRequestBarbershopOwnershipHandler(service as unknown as OwnershipService);

    const result = await callAs(handler, 'client1', { barbershopId: 'shop1' });

    expect(result).toEqual({ success: true });
    expect(service.requestOwnership).toHaveBeenCalledWith({ barbershopId: 'shop1', requestedBy: 'client1' });
  });
});
