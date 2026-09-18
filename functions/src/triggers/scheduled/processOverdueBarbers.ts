import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { BarberAvailabilityService } from '../../barbers/barberAvailabilityService';

/** [service] solo se sobreescribe en tests. */
export function createProcessOverdueBarbersHandler(service: BarberAvailabilityService = new BarberAvailabilityService()) {
  return onSchedule('every 5 minutes', async () => {
    const { barbersAffected, appointmentsPostponed } = await service.processOverdueBarbers();
    if (barbersAffected > 0) {
      logger.info(`processOverdueBarbers: ${barbersAffected} barbero(s), ${appointmentsPostponed} cita(s) aplazada(s)`);
    }
  });
}

export const processOverdueBarbers = createProcessOverdueBarbersHandler();
