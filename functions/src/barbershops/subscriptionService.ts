import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { slotId } from '../appointments/slotId';
import { dispatchAppointmentCancelledByBlockNotice, dispatchSubscriptionStatusNotice } from '../notifications/dispatchTemplatedNotification';
import { SimulatedNequiGateway } from '../payments/nequiGateway';
import { PaymentGatewayAdapter } from '../payments/types';
import { UPCOMING_APPOINTMENT_STATUSES } from '../shared/appointmentStatuses';
import { toJsDate } from '../shared/dateUtils';
import { assertOwnerOfShop } from '../shared/shopAuthorization';
import { CancelSubscriptionInput, PaySubscriptionInput } from './types';

// Placeholder hasta que el negocio defina el precio real de la mensualidad.
const MONTHLY_FEE = 50000;
const SUBSCRIPTION_PERIOD_MS = 30 * 24 * 60 * 60 * 1000;
// spec 12.5: período de gracia de 3 a 5 días — se usa el punto medio.
const GRACE_PERIOD_MS = 4 * 24 * 60 * 60 * 1000;

/**
 * Mensualidad de cada barbería (spec 12.5/12.6), independiente entre
 * barberías de un mismo dueño. [gateway] solo se sobreescribe en tests.
 */
export class SubscriptionService {
  constructor(private readonly gateway: PaymentGatewayAdapter = new SimulatedNequiGateway()) {}

  /** Paga/renueva la mensualidad: 30 días desde el pago, y reactiva la barbería si estaba bloqueada. */
  async paySubscription(input: PaySubscriptionInput): Promise<void> {
    await assertOwnerOfShop(input.requestedBy, input.barbershopId);

    const firestore = getFirestore();
    const shopRef = firestore.doc(`barbershops/${input.barbershopId}`);
    const shopSnap = await shopRef.get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'La barbería no existe.');
    const shop = shopSnap.data()!;

    if (shop.approvalStatus !== 'approved') {
      throw new HttpsError('failed-precondition', 'Esta barbería todavía no fue aprobada por el administrador.');
    }

    await this.gateway.requestPayment({
      payerId: input.requestedBy,
      amount: MONTHLY_FEE,
      category: 'subscription',
      relatedId: input.barbershopId,
      description: `Mensualidad de barbershops/${input.barbershopId}`,
    });

    await shopRef.update({
      paymentStatus: 'ok',
      paymentDueDate: new Date(Date.now() + SUBSCRIPTION_PERIOD_MS),
      active: true,
    });
  }

  /**
   * Cancelación directa de la membresía: bloquea de inmediato, sin período
   * de gracia — a diferencia del vencimiento por no pago, que sí lo tiene
   * (spec 12.5). Igual que el vencimiento, respeta las reservas dentro del
   * período ya pagado y cancela+reembolsa las que caen después (spec 12.6).
   */
  async cancelSubscription(input: CancelSubscriptionInput): Promise<void> {
    await assertOwnerOfShop(input.requestedBy, input.barbershopId);
    await this.blockBarbershop(input.barbershopId);
  }

  /**
   * Revisión periódica de mensualidades: al vencer entra en gracia; pasado
   * el período de gracia, se bloquea (spec 12.5/12.6).
   */
  async processBilling(now: Date = new Date()): Promise<{ overdue: number; blocked: number }> {
    const firestore = getFirestore();

    const dueSnap = await firestore
      .collection('barbershops')
      .where('paymentStatus', '==', 'ok')
      .where('paymentDueDate', '<=', now)
      .get();
    for (const doc of dueSnap.docs) {
      const shop = doc.data();
      await doc.ref.update({ paymentStatus: 'overdue' });
      await dispatchSubscriptionStatusNotice({ toUserId: shop.ownerId as string, kind: 'overdue', barbershopName: shop.name as string });
    }

    const graceLimit = new Date(now.getTime() - GRACE_PERIOD_MS);
    const overdueSnap = await firestore
      .collection('barbershops')
      .where('paymentStatus', '==', 'overdue')
      .where('paymentDueDate', '<=', graceLimit)
      .get();
    for (const doc of overdueSnap.docs) {
      await this.blockBarbershop(doc.id);
    }

    return { overdue: dueSnap.size, blocked: overdueSnap.size };
  }

  /**
   * El corte para decidir qué reservas se cancelan siempre es el
   * paymentDueDate vigente al momento del bloqueo — lo ya pagado no se
   * toca (spec 12.6).
   */
  private async blockBarbershop(barbershopId: string): Promise<void> {
    const firestore = getFirestore();
    const shopRef = firestore.doc(`barbershops/${barbershopId}`);
    const shopSnap = await shopRef.get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'La barbería no existe.');
    const shop = shopSnap.data()!;

    const cutoff = shop.paymentDueDate ? toJsDate(shop.paymentDueDate) : new Date();

    await shopRef.update({ paymentStatus: 'blocked', active: false });
    await dispatchSubscriptionStatusNotice({ toUserId: shop.ownerId as string, kind: 'blocked', barbershopName: shop.name as string });
    await this.cancelTrappedAppointments(barbershopId, shop.name as string, cutoff);
  }

  private async cancelTrappedAppointments(barbershopId: string, barbershopName: string, cutoff: Date): Promise<void> {
    const firestore = getFirestore();
    const appointmentsSnap = await firestore
      .collection('appointments')
      .where('barbershopId', '==', barbershopId)
      .where('date', '>', cutoff)
      .get();

    for (const doc of appointmentsSnap.docs) {
      const data = doc.data();
      if (data.paid !== true || !UPCOMING_APPOINTMENT_STATUSES.has(data.status as string)) continue;

      if (data.paymentId) {
        await this.gateway.refund(data.paymentId as string);
      }
      const slotRef = firestore.collection('appointmentSlots').doc(slotId(data.barberId as string, toJsDate(data.date)));
      await Promise.all([doc.ref.update({ status: 'cancelled' }), slotRef.delete()]);
      await dispatchAppointmentCancelledByBlockNotice({
        toUserId: data.clientId as string,
        barbershopName,
        serviceName: data.serviceName as string,
      });
    }
  }
}
