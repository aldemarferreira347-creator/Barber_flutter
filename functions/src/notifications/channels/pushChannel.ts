import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

import { ChannelResult, NotificationChannel, NotificationMessage, NotificationRecipient } from '../types';

const UNREGISTERED_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Push vía Firebase Cloud Messaging. Si algún token quedó inválido, lo retira del perfil. */
export const pushChannel: NotificationChannel = {
  name: 'push',

  async send(recipient: NotificationRecipient, message: NotificationMessage): Promise<ChannelResult> {
    if (recipient.fcmTokens.length === 0) return 'skipped';

    const response = await getMessaging().sendEachForMulticast({
      tokens: recipient.fcmTokens,
      notification: { title: message.title, body: message.body },
    });

    const deadTokens = response.responses
      .map((result, index) => ({ result, token: recipient.fcmTokens[index] }))
      .filter(({ result }) => !result.success && UNREGISTERED_TOKEN_ERRORS.has(result.error?.code ?? ''))
      .map(({ token }) => token);

    if (deadTokens.length > 0) {
      await getFirestore()
        .doc(`users/${recipient.uid}`)
        .update({ fcmTokens: FieldValue.arrayRemove(...deadTokens) })
        .catch((error) => logger.warn('No se pudieron limpiar tokens FCM vencidos', { uid: recipient.uid, error }));
    }

    return response.successCount > 0 ? 'sent' : 'skipped';
  },
};
