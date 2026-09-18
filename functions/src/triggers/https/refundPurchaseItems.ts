import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { PurchaseService } from '../../products/purchaseService';

/**
 * Reservado al admin por ahora, igual que refundPayment — el flujo real
 * con checklist y aprobación del dueño (spec 6.5/10.5) llega en una fase
 * posterior y reutilizará esta misma función.
 */
export function createRefundPurchaseItemsHandler(service: PurchaseService = new PurchaseService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const callerDoc = await getFirestore().doc(`users/${request.auth.uid}`).get();
    if (callerDoc.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo un administrador puede procesar este reembolso.');
    }

    const purchaseId = request.data?.purchaseId;
    const itemIndexes = request.data?.itemIndexes;
    if (typeof purchaseId !== 'string' || purchaseId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'purchaseId es obligatorio.');
    }
    if (!Array.isArray(itemIndexes) || itemIndexes.some((index) => typeof index !== 'number')) {
      throw new HttpsError('invalid-argument', 'itemIndexes debe ser un arreglo de números.');
    }

    await service.refundItems(purchaseId, itemIndexes);
    return { ok: true };
  });
}

export const refundPurchaseItems = createRefundPurchaseItemsHandler();
