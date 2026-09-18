import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { OwnershipService } from '../../barbershops/ownershipService';

interface RequestOwnershipRequest {
  barbershopId: unknown;
}

function validate(data: RequestOwnershipRequest) {
  const barbershopId = data.barbershopId;
  if (typeof barbershopId !== 'string' || barbershopId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'barbershopId es obligatorio.');
  }
  return { barbershopId };
}

export function createRequestBarbershopOwnershipHandler(service: OwnershipService = new OwnershipService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    await service.requestOwnership({ ...input, requestedBy: request.auth.uid });
    return { success: true };
  });
}

export const requestBarbershopOwnership = createRequestBarbershopOwnershipHandler();
