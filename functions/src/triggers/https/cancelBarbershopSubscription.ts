import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { SubscriptionService } from '../../barbershops/subscriptionService';

interface CancelSubscriptionRequest {
  barbershopId: unknown;
}

function validate(data: CancelSubscriptionRequest) {
  const barbershopId = data.barbershopId;
  if (typeof barbershopId !== 'string' || barbershopId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'barbershopId es obligatorio.');
  }
  return { barbershopId };
}

export function createCancelBarbershopSubscriptionHandler(service: SubscriptionService = new SubscriptionService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    await service.cancelSubscription({ ...input, requestedBy: request.auth.uid });
    return { success: true };
  });
}

export const cancelBarbershopSubscription = createCancelBarbershopSubscriptionHandler();
