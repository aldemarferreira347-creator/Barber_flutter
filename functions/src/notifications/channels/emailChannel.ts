import { logger } from 'firebase-functions';

import { ChannelResult, NotificationChannel, NotificationMessage, NotificationRecipient } from '../types';

/**
 * Canal de respaldo por correo (spec 3.1). Igual que smsChannel: sin
 * proveedor configurado (SendGrid u otro) no confirma entrega real, deja
 * constancia en el log y reporta 'skipped'.
 */
export const emailChannel: NotificationChannel = {
  name: 'email',

  async send(recipient: NotificationRecipient, message: NotificationMessage): Promise<ChannelResult> {
    if (!recipient.email) return 'skipped';
    logger.info('[email:pendiente-de-proveedor] no configurado, no se envía', { uid: recipient.uid, title: message.title });
    return 'skipped';
  },
};
