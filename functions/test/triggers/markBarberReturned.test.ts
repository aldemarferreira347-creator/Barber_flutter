import { HttpsError } from 'firebase-functions/v2/https';

import { createMarkBarberReturnedHandler } from '../../src/triggers/https/markBarberReturned';
import { BarberAvailabilityService } from '../../src/barbers/barberAvailabilityService';

function fakeService(): jest.Mocked<Pick<BarberAvailabilityService, 'markReturned'>> {
  return { markReturned: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createMarkBarberReturnedHandler>, uid: string | undefined) {
  return handler.run({ data: {}, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('markBarberReturned callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createMarkBarberReturnedHandler(service as unknown as BarberAvailabilityService);
    await expect(callAs(handler, undefined)).rejects.toBeInstanceOf(HttpsError);
  });

  it('delega en el servicio con el uid autenticado', async () => {
    const service = fakeService();
    const handler = createMarkBarberReturnedHandler(service as unknown as BarberAvailabilityService);

    const result = await callAs(handler, 'barber1');

    expect(result).toEqual({ ok: true });
    expect(service.markReturned).toHaveBeenCalledWith('barber1');
  });
});
