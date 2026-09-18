import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { BarberAvailabilityService } from '../../barbers/barberAvailabilityService';

export function createMarkBarberReturnedHandler(service: BarberAvailabilityService = new BarberAvailabilityService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    await service.markReturned(request.auth.uid);
    return { ok: true };
  });
}

export const markBarberReturned = createMarkBarberReturnedHandler();
