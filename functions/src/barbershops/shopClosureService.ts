import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { slotId } from '../appointments/slotId';
import { dispatchShopClosureNotice } from '../notifications/dispatchTemplatedNotification';
import { UPCOMING_APPOINTMENT_STATUSES } from '../shared/appointmentStatuses';
import { toJsDate } from '../shared/dateUtils';
import { assertOwnerOfShop } from '../shared/shopAuthorization';

export interface CloseShopInput {
  barbershopId: string;
  closedFrom: Date;
  closedUntil: Date;
  reason: string;
  requestedBy: string;
}

/**
 * Cierre de tienda por evento externo (spec 3.4): cada reserva PAGADA
 * dentro del rango cerrado queda aplazada (el cliente elige nueva fecha
 * desde la app, igual que en la fase 8), se notifica al cliente, y se
 * marca forcedRatingPenalty para que la fase de calificaciones descuente
 * 1 estrella obligatoriamente — el cierre no depende de la barbería, pero
 * igual afecta la experiencia del cliente.
 */
export class ShopClosureService {
  async closeForExternalEvent(input: CloseShopInput): Promise<{ closureId: string; appointmentsAffected: number }> {
    if (input.reason.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Debes indicar el motivo del cierre.');
    }
    if (input.closedUntil.getTime() <= input.closedFrom.getTime()) {
      throw new HttpsError('invalid-argument', 'closedUntil debe ser posterior a closedFrom.');
    }

    await assertOwnerOfShop(input.requestedBy, input.barbershopId);

    const firestore = getFirestore();
    const shopSnap = await firestore.doc(`barbershops/${input.barbershopId}`).get();
    const barbershopName = (shopSnap.data()?.name as string | undefined) ?? 'tu barbería';

    const closureRef = await firestore.collection('shopClosures').add({
      barbershopId: input.barbershopId,
      closedFrom: input.closedFrom,
      closedUntil: input.closedUntil,
      reason: input.reason.trim(),
      requestedBy: input.requestedBy,
      appointmentsAffected: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

    const appointmentsSnap = await firestore
      .collection('appointments')
      .where('barbershopId', '==', input.barbershopId)
      .where('date', '>=', input.closedFrom)
      .where('date', '<=', input.closedUntil)
      .get();

    let affected = 0;
    for (const doc of appointmentsSnap.docs) {
      const data = doc.data();
      if (data.paid !== true || !UPCOMING_APPOINTMENT_STATUSES.has(data.status as string)) continue;

      const slotRef = firestore.collection('appointmentSlots').doc(slotId(data.barberId as string, toJsDate(data.date)));
      await Promise.all([
        doc.ref.update({ status: 'postponed', forcedRatingPenalty: true }),
        slotRef.delete(),
      ]);
      await dispatchShopClosureNotice({ toUserId: data.clientId as string, barbershopName, serviceName: data.serviceName as string });
      affected++;
    }

    await closureRef.update({ appointmentsAffected: affected });

    return { closureId: closureRef.id, appointmentsAffected: affected };
  }
}
