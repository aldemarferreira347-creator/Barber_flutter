import { createSendAppointmentRemindersHandler } from '../../../src/triggers/scheduled/sendAppointmentReminders';
import { AppointmentReminderService } from '../../../src/appointments/reminderService';

function fakeService(result: { oneHour: number; fifteenMin: number }): jest.Mocked<Pick<AppointmentReminderService, 'sendDueReminders'>> {
  return { sendDueReminders: jest.fn().mockResolvedValue(result) };
}

describe('sendAppointmentReminders scheduled function', () => {
  it('llama a sendDueReminders en cada corrida', async () => {
    const service = fakeService({ oneHour: 2, fifteenMin: 1 });
    const handler = createSendAppointmentRemindersHandler(service as unknown as AppointmentReminderService);

    await handler.run({} as never);

    expect(service.sendDueReminders).toHaveBeenCalledTimes(1);
  });

  it('no falla cuando no hay recordatorios pendientes', async () => {
    const service = fakeService({ oneHour: 0, fifteenMin: 0 });
    const handler = createSendAppointmentRemindersHandler(service as unknown as AppointmentReminderService);

    await expect(handler.run({} as never)).resolves.toBeUndefined();
  });
});
