import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { PurchaseService } from '../../products/purchaseService';

/** [service] solo se sobreescribe en tests — en producción siempre es uno nuevo por invocación. */
export function createExpirePurchasesHandler(service: PurchaseService = new PurchaseService()) {
  return onSchedule('every 30 minutes', async () => {
    const count = await service.expireOverduePurchases();
    if (count > 0) {
      logger.info(`expirePurchases: ${count} compra(s) marcada(s) como vencida(s)`);
    }
  });
}

/** Libera a la barbería de responsabilidad sobre compras no reclamadas a tiempo (spec 10.4). */
export const expirePurchases = createExpirePurchasesHandler();
