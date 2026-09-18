import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

import { AppointmentReminderService } from '../../appointments/reminderService';

/** [service] solo se sobreescribe en tests. */
export function createSendAppointmentRemindersHandler(service: AppointmentReminderService = new AppointmentReminderService()) {
  return onSchedule('every 5 minutes', async () => {
    const { oneHour, fifteenMin } = await service.sendDueReminders();
    if (oneHour > 0 || fifteenMin > 0) {
      logger.info(`sendAppointmentReminders: ${oneHour} recordatorio(s) de 1h, ${fifteenMin} de 15min`);
    }
  });
}

export const sendAppointmentReminders = createSendAppointmentRemindersHandler();
