import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { SubscriptionService } from '../../barbershops/subscriptionService';

/** [service] solo se sobreescribe en tests. */
export function createProcessBarbershopBillingHandler(service: SubscriptionService = new SubscriptionService()) {
  return onSchedule('every 24 hours', async () => {
    const { overdue, blocked } = await service.processBilling();
    if (overdue > 0 || blocked > 0) {
      logger.info(`processBarbershopBilling: ${overdue} barbería(s) vencida(s), ${blocked} bloqueada(s)`);
    }
  });
}

export const processBarbershopBilling = createProcessBarbershopBillingHandler();
