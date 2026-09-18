import { dispatchNotification } from './notificationDispatcher';
import { renderBarberBack, renderRescheduleInvite } from './templates/barberAvailabilityTemplates';
import { renderAppointmentReminder, ReminderTemplateData } from './templates/appointmentReminderTemplates';
import { fetchNotificationRecipient } from './userDirectory';

/**
 * Envía un recordatorio de cita en el tono que el destinatario eligió
 * (spec 3.5), y luego delega en dispatchNotification — el mismo punto
 * único de entrega que usa cualquier otra notificación (spec 3.1). Prueba
 * en la práctica que el diseño de la fase 1 no necesitaba cambiar para
 * soportar un tipo de notificación nuevo.
 */
export async function dispatchAppointmentReminder(input: {
  toUserId: string;
  kind: '1h' | '15m';
  serviceName: string;
  barbershopName: string;
  time: string;
}): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';

  const data: ReminderTemplateData = {
    serviceName: input.serviceName,
    barbershopName: input.barbershopName,
    time: input.time,
  };
  const { title, body } = renderAppointmentReminder(input.kind, tone, data);

  await dispatchNotification({ toUserId: input.toUserId, title, body, category: 'appointment_reminder' });
}

/** El barbero no volvió dentro de su propio estimado (spec 3.3) — invita a reprogramar. */
export async function dispatchRescheduleInvite(input: { toUserId: string; serviceName: string }): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';
  const { title, body } = renderRescheduleInvite(tone, { serviceName: input.serviceName });
  await dispatchNotification({ toUserId: input.toUserId, title, body, category: 'barber_reschedule_invite' });
}

/** El barbero volvió a tiempo y hay una cita en la próxima hora (spec 3.3). */
export async function dispatchBarberBack(input: { toUserId: string; serviceName: string; time: string }): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';
  const { title, body } = renderBarberBack(tone, { serviceName: input.serviceName, time: input.time });
  await dispatchNotification({ toUserId: input.toUserId, title, body, category: 'barber_back_on_time' });
}
