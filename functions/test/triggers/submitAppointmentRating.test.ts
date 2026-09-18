import { HttpsError } from 'firebase-functions/v2/https';

import { createSubmitAppointmentRatingHandler } from '../../src/triggers/https/submitAppointmentRating';
import { RatingService } from '../../src/ratings/ratingService';

function fakeService(): jest.Mocked<Pick<RatingService, 'submitRating'>> {
  return { submitRating: jest.fn().mockResolvedValue({ ratingId: 'appt1' }) };
}

function callAs(handler: ReturnType<typeof createSubmitAppointmentRatingHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const VALID_PAYLOAD = { appointmentId: 'appt1', barberStars: 5, shopStars: 4 };

describe('submitAppointmentRating callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createSubmitAppointmentRatingHandler(service as unknown as RatingService);
    await expect(callAs(handler, undefined, VALID_PAYLOAD)).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin appointmentId', { ...VALID_PAYLOAD, appointmentId: '' }],
    ['barberStars no numérico', { ...VALID_PAYLOAD, barberStars: '5' }],
    ['shopStars no numérico', { ...VALID_PAYLOAD, shopStars: '4' }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createSubmitAppointmentRatingHandler(service as unknown as RatingService);
    await expect(callAs(handler, 'client1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.submitRating).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como clientId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createSubmitAppointmentRatingHandler(service as unknown as RatingService);

    const result = await callAs(handler, 'client1', { ...VALID_PAYLOAD, clientId: 'someone-else' });

    expect(result).toEqual({ ratingId: 'appt1' });
    expect(service.submitRating).toHaveBeenCalledWith({ appointmentId: 'appt1', barberStars: 5, shopStars: 4, clientId: 'client1' });
  });
});
