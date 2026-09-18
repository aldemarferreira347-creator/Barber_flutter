import { RatingService } from '../../src/ratings/ratingService';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  Timestamp: class FakeTimestamp {},
}));

function seedAppointment(id: string, overrides: Partial<Record<string, unknown>> = {}) {
  fakeFirestore.seed(`appointments/${id}`, {
    barbershopId: 'shop1',
    barberId: 'barber1',
    clientId: 'client1',
    status: 'completed',
    paid: true,
    forcedRatingPenalty: false,
    ...overrides,
  });
}

beforeEach(() => {
  fakeFirestore.reset();
  fakeFirestore.seed('barbershops/shop1', { name: 'BarberFlow Centro' });
  fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
});

describe('RatingService.submitRating', () => {
  it('guarda la calificación y acumula el promedio de la barbería y del barbero', async () => {
    seedAppointment('appt1');
    const service = new RatingService();

    const { ratingId } = await service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 5, shopStars: 4 });

    expect(ratingId).toBe('appt1');
    const rating = (await fakeFirestore.doc('ratings/appt1').get()).data()!;
    expect(rating).toMatchObject({ barberStars: 5, shopStars: 4, effectiveShopStars: 4, forcedRatingPenaltyApplied: false });

    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.ratingSum).toBe(4);
    expect(shop.ratingCount).toBe(1);

    const barber = (await fakeFirestore.doc('users/barber1').get()).data()!;
    expect(barber.ratingSum).toBe(5);
    expect(barber.ratingCount).toBe(1);
  });

  it('acumula sobre calificaciones previas de otras citas', async () => {
    fakeFirestore.seed('barbershops/shop1', { name: 'BarberFlow Centro', ratingSum: 8, ratingCount: 2 });
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1', ratingSum: 9, ratingCount: 2 });
    seedAppointment('appt1');
    const service = new RatingService();

    await service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 3, shopStars: 5 });

    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.ratingSum).toBe(13);
    expect(shop.ratingCount).toBe(3);
  });

  it('aplica el descuento obligatorio de 1 estrella al promedio de la barbería cuando hay forcedRatingPenalty', async () => {
    seedAppointment('appt1', { forcedRatingPenalty: true });
    const service = new RatingService();

    const { ratingId } = await service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 5, shopStars: 5 });

    const rating = (await fakeFirestore.doc(`ratings/${ratingId}`).get()).data()!;
    expect(rating.shopStars).toBe(5);
    expect(rating.effectiveShopStars).toBe(4);
    expect(rating.forcedRatingPenaltyApplied).toBe(true);

    const shop = (await fakeFirestore.doc('barbershops/shop1').get()).data()!;
    expect(shop.ratingSum).toBe(4);

    const barber = (await fakeFirestore.doc('users/barber1').get()).data()!;
    // El barbero no cargó con la culpa del cierre externo: su calificación no se descuenta.
    expect(barber.ratingSum).toBe(5);
  });

  it('el descuento nunca deja el efectivo por debajo de 1 estrella', async () => {
    seedAppointment('appt1', { forcedRatingPenalty: true });
    const service = new RatingService();

    const { ratingId } = await service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 1, shopStars: 1 });

    const rating = (await fakeFirestore.doc(`ratings/${ratingId}`).get()).data()!;
    expect(rating.effectiveShopStars).toBe(1);
  });

  it('rechaza estrellas fuera de rango o no enteras', async () => {
    seedAppointment('appt1');
    const service = new RatingService();

    await expect(service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 0, shopStars: 4 })).rejects.toThrow(
      'barberStars',
    );
    await expect(service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 3.5, shopStars: 4 })).rejects.toThrow(
      'barberStars',
    );
    await expect(service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 4, shopStars: 6 })).rejects.toThrow(
      'shopStars',
    );
  });

  it('rechaza calificar una cita ajena', async () => {
    seedAppointment('appt1');
    const service = new RatingService();

    await expect(
      service.submitRating({ appointmentId: 'appt1', clientId: 'otherClient', barberStars: 5, shopStars: 5 }),
    ).rejects.toThrow('Solo el cliente');
  });

  it('rechaza calificar una cita sin pago o no completada', async () => {
    seedAppointment('unpaid', { paid: false });
    seedAppointment('pending', { status: 'accepted' });
    const service = new RatingService();

    await expect(
      service.submitRating({ appointmentId: 'unpaid', clientId: 'client1', barberStars: 5, shopStars: 5 }),
    ).rejects.toThrow('pagada y completada');
    await expect(
      service.submitRating({ appointmentId: 'pending', clientId: 'client1', barberStars: 5, shopStars: 5 }),
    ).rejects.toThrow('pagada y completada');
  });

  it('rechaza calificar dos veces la misma cita', async () => {
    seedAppointment('appt1');
    const service = new RatingService();

    await service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 5, shopStars: 5 });

    await expect(
      service.submitRating({ appointmentId: 'appt1', clientId: 'client1', barberStars: 4, shopStars: 4 }),
    ).rejects.toThrow('Ya calificaste');
  });

  it('rechaza una cita inexistente', async () => {
    const service = new RatingService();
    await expect(
      service.submitRating({ appointmentId: 'ghost', clientId: 'client1', barberStars: 5, shopStars: 5 }),
    ).rejects.toThrow('no existe');
  });
});
