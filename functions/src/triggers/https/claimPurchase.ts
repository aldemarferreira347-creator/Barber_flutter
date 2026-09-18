import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { PurchaseService } from '../../products/purchaseService';

export function createClaimPurchaseHandler(service: PurchaseService = new PurchaseService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const purchaseId = request.data?.purchaseId;
    if (typeof purchaseId !== 'string' || purchaseId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'purchaseId es obligatorio.');
    }

    await service.claimPurchase(purchaseId, request.auth.uid);
    return { ok: true };
  });
}

export const claimPurchase = createClaimPurchaseHandler();
