import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { ShopClosureService } from '../../barbershops/shopClosureService';

const MAX_REASON_LENGTH = 300;

interface CloseShopRequest {
  barbershopId: unknown;
  closedFrom: unknown;
  closedUntil: unknown;
  reason: unknown;
}

function validate(data: CloseShopRequest) {
  const barbershopId = data.barbershopId;
  const reason = data.reason;

  if (typeof barbershopId !== 'string' || barbershopId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'barbershopId es obligatorio.');
  }
  if (typeof reason !== 'string' || reason.trim().length === 0 || reason.length > MAX_REASON_LENGTH) {
    throw new HttpsError('invalid-argument', `reason es obligatorio (máx. ${MAX_REASON_LENGTH} caracteres).`);
  }

  const closedFrom = typeof data.closedFrom === 'string' ? new Date(data.closedFrom) : null;
  const closedUntil = typeof data.closedUntil === 'string' ? new Date(data.closedUntil) : null;
  if (!closedFrom || Number.isNaN(closedFrom.getTime())) {
    throw new HttpsError('invalid-argument', 'closedFrom debe ser una fecha ISO válida.');
  }
  if (!closedUntil || Number.isNaN(closedUntil.getTime())) {
    throw new HttpsError('invalid-argument', 'closedUntil debe ser una fecha ISO válida.');
  }

  return { barbershopId, closedFrom, closedUntil, reason };
}

export function createCloseShopForExternalEventHandler(service: ShopClosureService = new ShopClosureService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    const result = await service.closeForExternalEvent({ ...input, requestedBy: request.auth.uid });
    return result;
  });
}

export const closeShopForExternalEvent = createCloseShopForExternalEventHandler();
