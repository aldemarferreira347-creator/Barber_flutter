import { HttpsError } from 'firebase-functions/v2/https';

import { createMarkBarberAwayHandler } from '../../src/triggers/https/markBarberAway';
import { BarberAvailabilityService } from '../../src/barbers/barberAvailabilityService';

function fakeService(): jest.Mocked<Pick<BarberAvailabilityService, 'markAway'>> {
  return { markAway: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createMarkBarberAwayHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('markBarberAway callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createMarkBarberAwayHandler(service as unknown as BarberAvailabilityService);
    await expect(callAs(handler, undefined, { estimatedMinutes: 30 })).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['no numérico', { estimatedMinutes: 'treinta' }],
    ['no entero', { estimatedMinutes: 30.5 }],
    ['muy corto', { estimatedMinutes: 1 }],
    ['muy largo', { estimatedMinutes: 500 }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createMarkBarberAwayHandler(service as unknown as BarberAvailabilityService);
    await expect(callAs(handler, 'barber1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.markAway).not.toHaveBeenCalled();
  });

  it('delega en el servicio con el uid autenticado', async () => {
    const service = fakeService();
    const handler = createMarkBarberAwayHandler(service as unknown as BarberAvailabilityService);

    const result = await callAs(handler, 'barber1', { estimatedMinutes: 30 });

    expect(result).toEqual({ ok: true });
    expect(service.markAway).toHaveBeenCalledWith('barber1', 30);
  });
});
