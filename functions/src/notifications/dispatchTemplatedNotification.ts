import { dispatchNotification } from './notificationDispatcher';
import { renderBarberBack, renderRescheduleInvite } from './templates/barberAvailabilityTemplates';
import { renderAppointmentReminder, ReminderTemplateData } from './templates/appointmentReminderTemplates';
import { renderShopClosureNotice } from './templates/shopClosureTemplates';
import { renderAppointmentCancelledByBlockNotice, renderSubscriptionStatusNotice } from './templates/subscriptionTemplates';
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

/** La barbería cerró por un evento externo y la cita pagada del cliente quedó aplazada (spec 3.4). */
export async function dispatchShopClosureNotice(input: { toUserId: string; barbershopName: string; serviceName: string }): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';
  const { title, body } = renderShopClosureNotice(tone, { barbershopName: input.barbershopName, serviceName: input.serviceName });
  await dispatchNotification({ toUserId: input.toUserId, title, body, category: 'shop_closure' });
}

/** Mensualidad vencida o bloqueada (spec 12.5/12.6): al dueño de la barbería. */
export async function dispatchSubscriptionStatusNotice(input: {
  toUserId: string;
  kind: 'overdue' | 'blocked';
  barbershopName: string;
}): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';
  const { title, body } = renderSubscriptionStatusNotice(input.kind, tone, { barbershopName: input.barbershopName });
  await dispatchNotification({
    toUserId: input.toUserId,
    title,
    body,
    category: input.kind === 'overdue' ? 'subscription_overdue' : 'subscription_blocked',
  });
}

/** La cita del cliente se canceló y reembolsó automáticamente por bloqueo de la barbería (spec 12.6). */
export async function dispatchAppointmentCancelledByBlockNotice(input: {
  toUserId: string;
  barbershopName: string;
  serviceName: string;
}): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  const tone = recipient?.notificationTone ?? 'normal';
  const { title, body } = renderAppointmentCancelledByBlockNotice(tone, {
    barbershopName: input.barbershopName,
    serviceName: input.serviceName,
  });
  await dispatchNotification({ toUserId: input.toUserId, title, body, category: 'appointment_cancelled_by_block' });
}
