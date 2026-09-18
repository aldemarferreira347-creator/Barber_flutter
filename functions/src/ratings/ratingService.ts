import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { SubmitRatingInput } from './types';

function assertValidStars(value: number, label: string) {
  if (!Number.isInteger(value) || value < 1 || value > 5) {
    throw new HttpsError('invalid-argument', `${label} debe ser un entero entre 1 y 5.`);
  }
}

/**
 * Calificaciones por estrellas (spec 7.1). Solo se puede calificar una
 * reserva pagada y completada (7.1), una sola vez por reserva — se usa el
 * propio appointmentId como id del documento de calificación, así un
 * segundo intento simplemente falla en vez de duplicar el conteo. Si el
 * cliente no califica, esa reserva no entra al promedio (no hay default).
 */
export class RatingService {
  async submitRating(input: SubmitRatingInput): Promise<{ ratingId: string }> {
    assertValidStars(input.barberStars, 'barberStars');
    assertValidStars(input.shopStars, 'shopStars');

    const firestore = getFirestore();
    const appointmentRef = firestore.collection('appointments').doc(input.appointmentId);
    const ratingRef = firestore.collection('ratings').doc(input.appointmentId);

    const appointmentSnap = await appointmentRef.get();
    if (!appointmentSnap.exists) throw new HttpsError('not-found', 'La cita no existe.');
    const appointment = appointmentSnap.data()!;

    if (appointment.clientId !== input.clientId) {
      throw new HttpsError('permission-denied', 'Solo el cliente de esa cita puede calificarla.');
    }
    if (appointment.paid !== true || appointment.status !== 'completed') {
      throw new HttpsError('failed-precondition', 'Solo se puede calificar una reserva pagada y completada.');
    }

    const existingRating = await ratingRef.get();
    if (existingRating.exists) {
      throw new HttpsError('already-exists', 'Ya calificaste esta cita.');
    }

    const barbershopRef = firestore.collection('barbershops').doc(appointment.barbershopId as string);
    const barberRef = firestore.collection('users').doc(appointment.barberId as string);

    // Cierre de tienda por evento externo (spec 3.4): descuento obligatorio
    // de 1 estrella en la calificación de la barbería (nunca en la del
    // barbero, que no tuvo responsabilidad en el cierre) — se aplica aquí,
    // sobre el promedio, y no puede evitarse eligiendo otro valor.
    const forcedPenalty = appointment.forcedRatingPenalty === true;
    const effectiveShopStars = forcedPenalty ? Math.max(1, input.shopStars - 1) : input.shopStars;

    await firestore.runTransaction(async (tx) => {
      const [barbershopSnap, barberSnap] = await Promise.all([tx.get(barbershopRef), tx.get(barberRef)]);
      const barbershop = barbershopSnap.data() ?? {};
      const barber = barberSnap.data() ?? {};

      const newShopSum = ((barbershop.ratingSum as number | undefined) ?? 0) + effectiveShopStars;
      const newShopCount = ((barbershop.ratingCount as number | undefined) ?? 0) + 1;
      const newBarberSum = ((barber.ratingSum as number | undefined) ?? 0) + input.barberStars;
      const newBarberCount = ((barber.ratingCount as number | undefined) ?? 0) + 1;

      tx.set(ratingRef, {
        appointmentId: input.appointmentId,
        barbershopId: appointment.barbershopId,
        barberId: appointment.barberId,
        clientId: input.clientId,
        barberStars: input.barberStars,
        shopStars: input.shopStars,
        effectiveShopStars,
        forcedRatingPenaltyApplied: forcedPenalty,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(barbershopRef, { ratingSum: newShopSum, ratingCount: newShopCount });
      tx.update(barberRef, { ratingSum: newBarberSum, ratingCount: newBarberCount });
    });

    return { ratingId: ratingRef.id };
  }
}
