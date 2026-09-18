import { HttpsError } from 'firebase-functions/v2/https';

import { createRequestAppointmentRefundHandler } from '../../src/triggers/https/requestAppointmentRefund';
import { AppointmentService } from '../../src/appointments/appointmentService';

function fakeService(): jest.Mocked<Pick<AppointmentService, 'requestRefund'>> {
  return { requestRefund: jest.fn().mockResolvedValue('req1') };
}

function callAs(handler: ReturnType<typeof createRequestAppointmentRefundHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

describe('requestAppointmentRefund callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createRequestAppointmentRefundHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, undefined, { appointmentId: 'appt1', reason: 'x' })).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin appointmentId', { reason: 'x' }],
    ['sin reason', { appointmentId: 'appt1' }],
    ['reason vacío', { appointmentId: 'appt1', reason: '   ' }],
    ['reason muy larga', { appointmentId: 'appt1', reason: 'a'.repeat(501) }],
    ['purchaseItemIndexes con no-números', { appointmentId: 'appt1', reason: 'x', purchaseId: 'p1', purchaseItemIndexes: ['a'] }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createRequestAppointmentRefundHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, 'client1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.requestRefund).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como clientId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createRequestAppointmentRefundHandler(service as unknown as AppointmentService);

    const result = await callAs(handler, 'client1', { appointmentId: 'appt1', reason: 'Tuve una emergencia', clientId: 'someone-else' });

    expect(result).toEqual({ id: 'req1' });
    expect(service.requestRefund).toHaveBeenCalledWith({
      appointmentId: 'appt1',
      reason: 'Tuve una emergencia',
      purchaseId: null,
      purchaseItemIndexes: null,
      clientId: 'client1',
    });
  });
});
