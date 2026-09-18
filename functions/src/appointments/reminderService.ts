import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { dispatchAppointmentReminder } from '../notifications/dispatchTemplatedNotification';
import { formatTimeUTC, toJsDate } from '../shared/dateUtils';

const UPCOMING_STATUSES = new Set(['pending', 'accepted', 'postponed']);
// Un poco más de 60 min de margen para no perder el borde entre corridas
// (la función se programa cada 5 minutos).
const WINDOW_MINUTES = 65;

/**
 * Recordatorios automáticos 1h y 15min antes de la cita (spec 3.2). Cada
 * cita solo puede disparar cada recordatorio una vez — se marca en su
 * propio documento (reminder1hSentAt/reminder15mSentAt) para que corridas
 * repetidas cada 5 minutos no lo dupliquen.
 */
export class AppointmentReminderService {
  async sendDueReminders(now: Date = new Date()): Promise<{ oneHour: number; fifteenMin: number }> {
    const firestore = getFirestore();
    const windowEnd = new Date(now.getTime() + WINDOW_MINUTES * 60_000);

    const snapshot = await firestore.collection('appointments').where('date', '>=', now).where('date', '<=', windowEnd).get();

    let oneHourCount = 0;
    let fifteenMinCount = 0;
    const barbershopNames = new Map<string, string>();

    const resolveBarbershopName = async (barbershopId: string): Promise<string> => {
      const cached = barbershopNames.get(barbershopId);
      if (cached) return cached;
      const snap = await firestore.doc(`barbershops/${barbershopId}`).get();
      const name = (snap.data()?.name as string | undefined) ?? 'tu barbería';
      barbershopNames.set(barbershopId, name);
      return name;
    };

    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (!UPCOMING_STATUSES.has(data.status as string)) continue;

      const date = toJsDate(data.date);
      const minutesUntil = (date.getTime() - now.getTime()) / 60_000;
      const time = formatTimeUTC(date);

      if (minutesUntil <= 60 && minutesUntil > 15 && !data.reminder1hSentAt) {
        const barbershopName = await resolveBarbershopName(data.barbershopId as string);
        await dispatchAppointmentReminder({
          toUserId: data.clientId as string,
          kind: '1h',
          serviceName: data.serviceName as string,
          barbershopName,
          time,
        });
        await doc.ref.update({ reminder1hSentAt: FieldValue.serverTimestamp() });
        oneHourCount++;
      }

      if (minutesUntil <= 15 && minutesUntil > 0 && !data.reminder15mSentAt) {
        const barbershopName = await resolveBarbershopName(data.barbershopId as string);
        await dispatchAppointmentReminder({
          toUserId: data.clientId as string,
          kind: '15m',
          serviceName: data.serviceName as string,
          barbershopName,
          time,
        });
        await doc.ref.update({ reminder15mSentAt: FieldValue.serverTimestamp() });
        fifteenMinCount++;
      }
    }

    return { oneHour: oneHourCount, fifteenMin: fifteenMinCount };
  }
}
