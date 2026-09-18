import { getFirestore } from 'firebase-admin/firestore';

import { NotificationRecipient, NotificationTone } from './types';

const VALID_TONES: readonly NotificationTone[] = ['formal', 'normal', 'friendly', 'informal'];

function parseTone(value: unknown): NotificationTone {
  return typeof value === 'string' && (VALID_TONES as readonly string[]).includes(value) ? (value as NotificationTone) : 'normal';
}

/** Carga los datos de users/{uid} que necesita el sistema de notificaciones, o null si no existe. */
export async function fetchNotificationRecipient(uid: string): Promise<NotificationRecipient | null> {
  const snapshot = await getFirestore().doc(`users/${uid}`).get();
  if (!snapshot.exists) return null;

  const data = snapshot.data() ?? {};
  return {
    uid,
    fcmTokens: Array.isArray(data.fcmTokens) ? data.fcmTokens.filter((t): t is string => typeof t === 'string') : [],
    phone: typeof data.phone === 'string' ? data.phone : null,
    email: typeof data.email === 'string' ? data.email : null,
    notificationTone: parseTone(data.notificationTone),
  };
}
