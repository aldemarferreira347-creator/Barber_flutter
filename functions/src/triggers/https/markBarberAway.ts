import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BarberAvailabilityService } from '../../barbers/barberAvailabilityService';

const MIN_MINUTES = 5;
const MAX_MINUTES = 240;

export function createMarkBarberAwayHandler(service: BarberAvailabilityService = new BarberAvailabilityService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const estimatedMinutes = request.data?.estimatedMinutes;
    if (
      typeof estimatedMinutes !== 'number' ||
      !Number.isInteger(estimatedMinutes) ||
      estimatedMinutes < MIN_MINUTES ||
      estimatedMinutes > MAX_MINUTES
    ) {
      throw new HttpsError('invalid-argument', `estimatedMinutes debe ser un entero entre ${MIN_MINUTES} y ${MAX_MINUTES}.`);
    }

    await service.markAway(request.auth.uid, estimatedMinutes);
    return { ok: true };
  });
}

export const markBarberAway = createMarkBarberAwayHandler();
