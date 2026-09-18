import { HttpsError } from 'firebase-functions/v2/https';

import { createBookPaidAppointmentHandler } from '../../src/triggers/https/bookPaidAppointment';
import { AppointmentService } from '../../src/appointments/appointmentService';

function fakeService(): jest.Mocked<Pick<AppointmentService, 'bookPaidAppointment'>> {
  return { bookPaidAppointment: jest.fn().mockResolvedValue('appt1') };
}

function callAs(handler: ReturnType<typeof createBookPaidAppointmentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const VALID_PAYLOAD = {
  barbershopId: 'shop1',
  barberId: 'barber1',
  barberName: 'Beto',
  serviceId: 'svc1',
  clientName: 'Ana',
  date: new Date(Date.now() + 3600_000).toISOString(),
};

describe('bookPaidAppointment callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createBookPaidAppointmentHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, undefined, VALID_PAYLOAD)).rejects.toBeInstanceOf(HttpsError);
    expect(service.bookPaidAppointment).not.toHaveBeenCalled();
  });

  it.each([
    ['sin barbershopId', { ...VALID_PAYLOAD, barbershopId: undefined }],
    ['sin barberId', { ...VALID_PAYLOAD, barberId: '' }],
    ['sin serviceId', { ...VALID_PAYLOAD, serviceId: undefined }],
    ['fecha inválida', { ...VALID_PAYLOAD, date: 'no-es-fecha' }],
    ['fecha en el pasado', { ...VALID_PAYLOAD, date: new Date(Date.now() - 3600_000).toISOString() }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createBookPaidAppointmentHandler(service as unknown as AppointmentService);
    await expect(callAs(handler, 'client1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.bookPaidAppointment).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como clientId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createBookPaidAppointmentHandler(service as unknown as AppointmentService);

    const result = await callAs(handler, 'client1', { ...VALID_PAYLOAD, clientId: 'someone-else' });

    expect(result).toEqual({ id: 'appt1' });
    expect(service.bookPaidAppointment).toHaveBeenCalledWith(expect.objectContaining({ clientId: 'client1', barbershopId: 'shop1' }));
  });

  it('propaga el error de horario ocupado del servicio', async () => {
    const service = fakeService();
    service.bookPaidAppointment.mockRejectedValue(new HttpsError('already-exists', 'Ese horario ya no está disponible.'));
    const handler = createBookPaidAppointmentHandler(service as unknown as AppointmentService);

    await expect(callAs(handler, 'client1', VALID_PAYLOAD)).rejects.toMatchObject({ code: 'already-exists' });
  });
});
