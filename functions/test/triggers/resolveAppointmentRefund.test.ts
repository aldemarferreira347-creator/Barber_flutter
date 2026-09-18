import { HttpsError } from 'firebase-functions/v2/https';

import { createResolveAppointmentRefundHandler } from '../../src/triggers/https/resolveAppointmentRefund';
import { AppointmentService } from '../../src/appointments/appointmentService';

function fakeService(): jest.Mocked<Pick<AppointmentService, 'resolveRefundRequest'>> {
  return { resolveRefundRequest: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createResolveAppointmentRefundHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('resolveAppointmentRefund callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createResolveAppointmentRefundHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, undefined, { requestId: 'req1', approve: true })).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin requestId', { approve: true }],
    ['approve no booleano', { requestId: 'req1', approve: 'yes' }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createResolveAppointmentRefundHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, 'owner1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.resolveRefundRequest).not.toHaveBeenCalled();
  });

  it('delega en el servicio, que resuelve la autorización real por barbería', async () => {
    const service = fakeService();
    const handler = createResolveAppointmentRefundHandler(service as unknown as AppointmentService);

    const result = await callAs(handler, 'owner1', { requestId: 'req1', approve: true });

    expect(result).toEqual({ ok: true });
    expect(service.resolveRefundRequest).toHaveBeenCalledWith('req1', 'owner1', true);
  });

  it('propaga el rechazo de autorización del servicio', async () => {
    const service = fakeService();
    service.resolveRefundRequest.mockRejectedValue(new HttpsError('permission-denied', 'Solo el dueño de esa barbería puede hacer esto.'));
    const handler = createResolveAppointmentRefundHandler(service as unknown as AppointmentService);

    await expect(callAs(handler, 'barber1', { requestId: 'req1', approve: true })).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
