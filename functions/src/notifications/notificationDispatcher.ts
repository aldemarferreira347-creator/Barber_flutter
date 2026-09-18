import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

import { emailChannel } from './channels/emailChannel';
import { pushChannel } from './channels/pushChannel';
import { smsChannel } from './channels/smsChannel';
import { DispatchNotificationInput, NotificationChannel } from './types';
import { fetchNotificationRecipient } from './userDirectory';

/**
 * Orden de intento: push primero (gratis, inmediato); si no hay token o
 * falla, cae a SMS y después a correo. Cualquier tipo de notificación
 * futura (recordatorios, aplazamientos, cierres, reembolsos...) pasa por
 * este mismo flujo — nunca por su cuenta — así una funcionalidad nueva no
 * puede romper la entrega de las que ya existen (spec 3.1).
 */
const CHANNELS: readonly NotificationChannel[] = [pushChannel, smsChannel, emailChannel];

/**
 * Punto único de envío de notificaciones de todo el sistema. [channels] solo
 * se sobreescribe en tests — en producción siempre se usa la cadena real.
 */
export async function dispatchNotification(
  input: DispatchNotificationInput,
  channels: readonly NotificationChannel[] = CHANNELS,
): Promise<void> {
  const recipient = await fetchNotificationRecipient(input.toUserId);
  if (!recipient) {
    logger.warn('dispatchNotification: destinatario inexistente, se descarta', { toUserId: input.toUserId });
    return;
  }

  const message = { title: input.title, body: input.body };

  const notificationRef = await getFirestore().collection('notifications').add({
    toUserId: input.toUserId,
    title: message.title,
    body: message.body,
    type: input.category,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  for (const channel of channels) {
    const result = await channel.send(recipient, message);
    if (result === 'sent') {
      logger.info('Notificación entregada', { notificationId: notificationRef.id, channel: channel.name });
      return;
    }
  }

  logger.warn('Notificación registrada pero no se pudo entregar por ningún canal', {
    notificationId: notificationRef.id,
    toUserId: input.toUserId,
  });
}
