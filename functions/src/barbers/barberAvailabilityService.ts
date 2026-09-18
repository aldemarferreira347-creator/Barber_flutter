import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { slotId } from '../appointments/slotId';
import { dispatchBarberBack, dispatchRescheduleInvite } from '../notifications/dispatchTemplatedNotification';
import { endOfDayUTC, formatTimeUTC, toJsDate } from '../shared/dateUtils';

const UPCOMING_STATUSES = new Set(['pending', 'accepted', 'postponed']);
const ONE_HOUR_MS = 60 * 60_000;

/**
 * Seguimiento de disponibilidad del barbero (spec 3.3): salida con
 * estimado propio, regreso, y aplazamiento automático de sus reservas
 * pagadas si no vuelve a tiempo — el límite nunca es un valor fijo, sale
 * siempre del propio estimado que el barbero declaró al salir.
 */
export class BarberAvailabilityService {
  async markAway(barberId: string, estimatedMinutes: number): Promise<void> {
    const userRef = getFirestore().doc(`users/${barberId}`);
    const snapshot = await userRef.get();
    if (!snapshot.exists || snapshot.data()?.role !== 'barber') {
      throw new HttpsError('failed-precondition', 'Solo un barbero puede marcar su salida.');
    }

    const now = new Date();
    await userRef.update({
      awaySince: now,
      awayUntilEstimate: new Date(now.getTime() + estimatedMinutes * 60_000),
    });
  }

  /** Si vuelve a tiempo y hay una cita en la próxima hora, confirma que sigue en pie. */
  async markReturned(barberId: string): Promise<void> {
    const firestore = getFirestore();
    const userRef = firestore.doc(`users/${barberId}`);
    const snapshot = await userRef.get();
    if (!snapshot.exists || snapshot.data()?.role !== 'barber') {
      throw new HttpsError('failed-precondition', 'Solo un barbero puede marcar su regreso.');
    }

    await userRef.update({ awaySince: null, awayUntilEstimate: null });

    const now = new Date();
    const withinNextHour = new Date(now.getTime() + ONE_HOUR_MS);
    const appointmentsSnap = await firestore
      .collection('appointments')
      .where('barberId', '==', barberId)
      .where('date', '>=', now)
      .where('date', '<=', withinNextHour)
      .get();

    for (const doc of appointmentsSnap.docs) {
      const data = doc.data();
      if (!UPCOMING_STATUSES.has(data.status as string)) continue;

      await dispatchBarberBack({
        toUserId: data.clientId as string,
        serviceName: data.serviceName as string,
        time: formatTimeUTC(toJsDate(data.date)),
      });
    }
  }

  /**
   * Corrida periódica: barberos cuyo propio estimado ya venció sin marcar
   * regreso. Sus reservas PAGADAS del resto de hoy quedan 'postponed' (sin
   * elegir fecha nueva todavía — el cliente la elige desde la app) y se
   * libera el horario bloqueado; las reservas sin pago no se tocan, no
   * bloqueaban nada.
   */
  async processOverdueBarbers(now: Date = new Date()): Promise<{ barbersAffected: number; appointmentsPostponed: number }> {
    const firestore = getFirestore();
    const overdueSnap = await firestore.collection('users').where('role', '==', 'barber').where('awayUntilEstimate', '<=', now).get();

    let barbersAffected = 0;
    let appointmentsPostponed = 0;

    for (const barberDoc of overdueSnap.docs) {
      const barberId = barberDoc.id;
      const endOfToday = endOfDayUTC(now);

      const appointmentsSnap = await firestore
        .collection('appointments')
        .where('barberId', '==', barberId)
        .where('date', '>=', now)
        .where('date', '<=', endOfToday)
        .get();

      let barberHadAffectedAppointments = false;
      for (const apptDoc of appointmentsSnap.docs) {
        const data = apptDoc.data();
        if (data.paid !== true || !UPCOMING_STATUSES.has(data.status as string)) continue;

        const slotRef = firestore.collection('appointmentSlots').doc(slotId(barberId, toJsDate(data.date)));
        await Promise.all([apptDoc.ref.update({ status: 'postponed' }), slotRef.delete()]);
        await dispatchRescheduleInvite({ toUserId: data.clientId as string, serviceName: data.serviceName as string });

        appointmentsPostponed++;
        barberHadAffectedAppointments = true;
      }

      // Se limpia el estimado para no reprocesar al mismo barbero en cada corrida.
      await barberDoc.ref.update({ awayUntilEstimate: null });
      if (barberHadAffectedAppointments) barbersAffected++;
    }

    return { barbersAffected, appointmentsPostponed };
  }
}
