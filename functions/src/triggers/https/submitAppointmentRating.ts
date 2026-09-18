import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { RatingService } from '../../ratings/ratingService';

interface SubmitRatingRequest {
  appointmentId: unknown;
  barberStars: unknown;
  shopStars: unknown;
}

function validate(data: SubmitRatingRequest) {
  const appointmentId = data.appointmentId;
  const barberStars = data.barberStars;
  const shopStars = data.shopStars;

  if (typeof appointmentId !== 'string' || appointmentId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'appointmentId es obligatorio.');
  }
  if (typeof barberStars !== 'number' || typeof shopStars !== 'number') {
    throw new HttpsError('invalid-argument', 'barberStars y shopStars deben ser números.');
  }

  return { appointmentId, barberStars, shopStars };
}

export function createSubmitAppointmentRatingHandler(service: RatingService = new RatingService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    return service.submitRating({ ...input, clientId: request.auth.uid });
  });
}

export const submitAppointmentRating = createSubmitAppointmentRatingHandler();
