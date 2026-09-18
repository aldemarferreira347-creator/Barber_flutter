import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { dispatchNotification } from '../../notifications/notificationDispatcher';
import { NotificationCategory } from '../../notifications/types';

const ALLOWED_CATEGORIES: readonly NotificationCategory[] = ['manual', 'auto_payment_overdue'];
const MAX_TITLE_LENGTH = 120;
const MAX_BODY_LENGTH = 1000;

interface SendNotificationRequest {
  toUserId: unknown;
  title: unknown;
  body: unknown;
  category?: unknown;
}

function validate(data: SendNotificationRequest) {
  const toUserId = data.toUserId;
  const title = data.title;
  const body = data.body;
  const category = data.category ?? 'manual';

  if (typeof toUserId !== 'string' || toUserId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'toUserId es obligatorio.');
  }
  if (typeof title !== 'string' || title.trim().length === 0 || title.length > MAX_TITLE_LENGTH) {
    throw new HttpsError('invalid-argument', `title es obligatorio (máx. ${MAX_TITLE_LENGTH} caracteres).`);
  }
  if (typeof body !== 'string' || body.trim().length === 0 || body.length > MAX_BODY_LENGTH) {
    throw new HttpsError('invalid-argument', `body es obligatorio (máx. ${MAX_BODY_LENGTH} caracteres).`);
  }
  if (typeof category !== 'string' || !ALLOWED_CATEGORIES.includes(category as NotificationCategory)) {
    throw new HttpsError('invalid-argument', 'category inválida.');
  }

  return { toUserId, title: title.trim(), body: body.trim(), category: category as NotificationCategory };
}

/**
 * Único punto de entrada para que la app envíe una notificación "literal"
 * (contenido ya redactado por quien la envía, p.ej. el aviso manual del
 * admin o el aviso automático de pago vencido) — pasa igual que cualquier
 * notificación del sistema por dispatchNotification, así comparte entrega
 * push/SMS/correo con todo lo demás.
 */
export const sendNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const callerDoc = await getFirestore().doc(`users/${request.auth.uid}`).get();
  if (callerDoc.data()?.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo un administrador puede enviar notificaciones.');
  }

  const input = validate(request.data ?? {});
  await dispatchNotification(input);
  return { ok: true };
});
