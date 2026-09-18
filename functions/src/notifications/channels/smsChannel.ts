import { logger } from 'firebase-functions';

import { ChannelResult, NotificationChannel, NotificationMessage, NotificationRecipient } from '../types';

/**
 * Canal de respaldo por SMS (spec 3.1). Sin credenciales de un proveedor
 * (Twilio u otro) todavía no puede confirmar una entrega real, así que deja
 * constancia en el log y reporta 'skipped' para que el dispatcher siga
 * probando el siguiente canal — nunca reporta 'sent' sin haber entregado
 * de verdad. El día que haya credenciales, solo este archivo cambia.
 */
export const smsChannel: NotificationChannel = {
  name: 'sms',

  async send(recipient: NotificationRecipient, message: NotificationMessage): Promise<ChannelResult> {
    if (!recipient.phone) return 'skipped';
    logger.info('[sms:pendiente-de-proveedor] no configurado, no se envía', { uid: recipient.uid, title: message.title });
    return 'skipped';
  },
};
