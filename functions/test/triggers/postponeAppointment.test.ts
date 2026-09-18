import { HttpsError } from 'firebase-functions/v2/https';

import { createPostponeAppointmentHandler } from '../../src/triggers/https/postponeAppointment';
import { AppointmentService } from '../../src/appointments/appointmentService';

function fakeService(): jest.Mocked<Pick<AppointmentService, 'postponePaidAppointment'>> {
  return { postponePaidAppointment: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createPostponeAppointmentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const futureIso = new Date(Date.now() + 3600_000).toISOString();

describe('postponeAppointment callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createPostponeAppointmentHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, undefined, { appointmentId: 'appt1', newDate: futureIso })).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin appointmentId', { newDate: futureIso }],
    ['fecha inválida', { appointmentId: 'appt1', newDate: 'no-es-fecha' }],
    ['fecha en el pasado', { appointmentId: 'appt1', newDate: new Date(Date.now() - 3600_000).toISOString() }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createPostponeAppointmentHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, 'client1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.postponePaidAppointment).not.toHaveBeenCalled();
  });

  it('delega en el servicio con el uid autenticado', async () => {
    const service = fakeService();
    const handler = createPostponeAppointmentHandler(service as unknown as AppointmentService);

    const result = await callAs(handler, 'client1', { appointmentId: 'appt1', newDate: futureIso });

    expect(result).toEqual({ ok: true });
    expect(service.postponePaidAppointment).toHaveBeenCalledWith('appt1', 'client1', new Date(futureIso));
  });
});
