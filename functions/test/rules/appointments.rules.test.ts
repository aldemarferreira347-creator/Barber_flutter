import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, Timestamp, updateDoc, writeBatch } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const CLIENT_UID = 'client1';
const BARBER_UID = 'barber1';
const OWNER_UID = 'owner1';

describe('firestore.rules — appointments/{id} (paid)', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID });
      await setDoc(doc(db, `users/${CLIENT_UID}`), { role: 'client' });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
    });
  });

  it('el cliente puede crear una cita sin pago (paid: false)', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: false,
      }),
    );
  });

  it('el cliente NO puede crear directamente una cita marcada paid: true', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertFails(
      setDoc(doc(db, 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: true,
        paymentId: 'fake-payment',
      }),
    );
  });

  it('el cliente puede cancelar directamente su cita SIN pago', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: false,
        paymentId: null,
      });
    });
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertSucceeds(updateDoc(doc(db, 'appointments/appt1'), { status: 'cancelled' }));
  });

  it('el cliente NO puede cancelar directamente una cita PAGADA (debe pasar por el reembolso)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: true,
        paymentId: 'payment1',
      });
    });
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertFails(updateDoc(doc(db, 'appointments/appt1'), { status: 'cancelled' }));
  });

  it('ni siquiera el dueño puede alterar paid/paymentId en una actualización normal', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: true,
        paymentId: 'payment1',
      });
      await setDoc(doc(context.firestore(), 'payments/payment1'), {
        payerId: CLIENT_UID,
        amount: 20000,
        category: 'appointment',
        relatedId: 'appt1',
        status: 'approved',
      });
    });
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, 'appointments/appt1'), { status: 'accepted', paid: false }));
    await assertSucceeds(updateDoc(doc(db, 'appointments/appt1'), { status: 'accepted' }));
  });

  it('ni el dueño puede quitarse la penalización forzada de calificación (spec 3.4)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appointments/appt2'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'postponed',
        paid: true,
        paymentId: 'payment1',
        forcedRatingPenalty: true,
      });
    });
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, 'appointments/appt2'), { forcedRatingPenalty: false }));
  });
});

const SERVICE_ID = 'svc1';
const SERVICE_PRICE = 20000;
const APPT_DATE = new Date('2030-06-01T15:00:30Z');
const slotIdOf = (barberId: string, date: Date) => `${barberId}_${date.toISOString().slice(0, 16)}`;

const paidAppointment = (overrides: Record<string, unknown> = {}) => ({
  clientId: CLIENT_UID,
  barbershopId: SHOP_ID,
  barberId: BARBER_UID,
  serviceId: SERVICE_ID,
  servicePrice: SERVICE_PRICE,
  date: Timestamp.fromDate(APPT_DATE),
  status: 'pending',
  paid: true,
  paymentId: 'pay1',
  rescheduleHistory: [],
  forcedRatingPenalty: false,
  ...overrides,
});

describe('firestore.rules — reserva pagada, identidad inmutable y slots', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID });
      await setDoc(doc(db, `barbershops/${SHOP_ID}/services/${SERVICE_ID}`), { active: true, price: SERVICE_PRICE });
      await setDoc(doc(db, `users/${CLIENT_UID}`), { role: 'client' });
      await setDoc(doc(db, 'users/attacker1'), { role: 'client' });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, 'payments/pay1'), { payerId: CLIENT_UID, category: 'appointment', relatedId: 'apptNew', status: 'pending', amount: SERVICE_PRICE });
      await setDoc(doc(db, 'payments/payReused'), { payerId: CLIENT_UID, category: 'appointment', relatedId: 'otroAppt', status: 'approved', amount: SERVICE_PRICE });
      await setDoc(doc(db, 'payments/paySub'), { payerId: CLIENT_UID, category: 'subscription', relatedId: 'apptNew', status: 'pending', amount: 50000 });
    });
  });

  describe('crear una cita pagada', () => {
    it('acepta la cita con SU pago de cita, pendiente y atado a este id', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'appointments/apptNew'), paidAppointment()));
    });

    it('rechaza reutilizar un pago que pertenece a otra cita', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/apptNew'), paidAppointment({ paymentId: 'payReused' })));
    });

    it('rechaza un pago de otra categoría (suscripción)', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/apptNew'), paidAppointment({ paymentId: 'paySub' })));
    });

    it('rechaza un pago por un monto distinto al precio del servicio', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'payments/payBajo'), { payerId: CLIENT_UID, category: 'appointment', relatedId: 'apptNew', status: 'pending', amount: 1 });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/apptNew'), paidAppointment({ paymentId: 'payBajo' })));
    });
  });

  describe('campos de identidad de la cita', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'appointments/apptP'), paidAppointment({ status: 'accepted' }));
      });
    });

    it('el cliente pospone su cita pagada sin tocar identidad ni precio', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertSucceeds(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', date: Timestamp.fromDate(new Date('2030-06-02T15:00:00Z')) }));
    });

    it('el cliente NO puede cambiar precio, servicio, barbería ni cliente al posponer', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', servicePrice: 1 }));
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', serviceId: 'otro' }));
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', barbershopId: 'shopZ' }));
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', clientId: 'attacker1' }));
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', barberId: 'otro-barbero' }));
      await assertFails(updateDoc(doc(db, 'appointments/apptP'), { status: 'postponed', durationMinutes: 1 }));
    });

    it('el barbero y el dueño actualizan estado pero NO el precio ni el cliente', async () => {
      for (const uid of [BARBER_UID, OWNER_UID]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        await assertSucceeds(updateDoc(doc(db, 'appointments/apptP'), { status: 'completed' }));
        await assertFails(updateDoc(doc(db, 'appointments/apptP'), { servicePrice: 1 }));
        await assertFails(updateDoc(doc(db, 'appointments/apptP'), { clientId: 'attacker1' }));
      }
    });
  });

  describe('appointmentSlots/{id}', () => {
    const goodSlot = { appointmentId: 'apptNew', barberId: BARBER_UID, createdAt: new Date() };

    it('nadie lee un slot directamente', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(getDoc(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`)));
    });

    it('el cliente reserva: cita + slot del minuto exacto en la MISMA transacción', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      const batch = writeBatch(db);
      batch.set(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`), goodSlot);
      batch.set(doc(db, 'appointments/apptNew'), paidAppointment());
      await assertSucceeds(batch.commit());
    });

    it('NO se puede crear un slot suelto, sin cita (bloqueo de agenda ajena)', async () => {
      const db = testEnv.authenticatedContext('attacker1').firestore();
      await assertFails(setDoc(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`), goodSlot));
    });

    it('NO se puede crear un slot con un id que no corresponde al minuto de la cita', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      const batch = writeBatch(db);
      batch.set(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, new Date('2030-06-01T16:00:00Z'))}`), goodSlot);
      batch.set(doc(db, 'appointments/apptNew'), paidAppointment());
      await assertFails(batch.commit());
    });

    it('NO se puede atar un slot a la cita de otro cliente', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'appointments/apptVictim'), paidAppointment({ paymentId: 'payReused' }));
      });
      const db = testEnv.authenticatedContext('attacker1').firestore();
      await assertFails(
        setDoc(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`), { ...goodSlot, appointmentId: 'apptVictim' }),
      );
    });

    describe('borrar', () => {
      beforeEach(async () => {
        await testEnv.withSecurityRulesDisabled(async (context) => {
          const fs = context.firestore();
          await setDoc(doc(fs, 'appointments/apptNew'), paidAppointment());
          await setDoc(doc(fs, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`), goodSlot);
        });
      });

      it('un tercero NO puede liberar el horario de una cita ajena', async () => {
        const db = testEnv.authenticatedContext('attacker1').firestore();
        await assertFails(deleteDoc(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`)));
      });

      it('el cliente de la cita, su barbero y el dueño de la barbería sí pueden', async () => {
        for (const uid of [CLIENT_UID, BARBER_UID, OWNER_UID]) {
          await testEnv.withSecurityRulesDisabled(async (context) => {
            await setDoc(doc(context.firestore(), `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`), goodSlot);
          });
          const db = testEnv.authenticatedContext(uid).firestore();
          await assertSucceeds(deleteDoc(doc(db, `appointmentSlots/${slotIdOf(BARBER_UID, APPT_DATE)}`)));
        }
      });
    });
  });
});

describe('firestore.rules — refundRequests/{id}', () => {
  let testEnv: RulesTestEnvironment;
  const REQUEST_ID = 'req1';

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID });
      await setDoc(doc(db, `refundRequests/${REQUEST_ID}`), {
        appointmentId: 'appt1',
        barbershopId: SHOP_ID,
        clientId: CLIENT_UID,
        status: 'pending',
      });
    });
  });

  it('el cliente que la creó puede leerla', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `refundRequests/${REQUEST_ID}`)));
  });

  it('el dueño de esa barbería puede leerla', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `refundRequests/${REQUEST_ID}`)));
  });

  it('un desconocido no puede leerla', async () => {
    const db = testEnv.authenticatedContext('stranger1').firestore();
    await assertFails(getDoc(doc(db, `refundRequests/${REQUEST_ID}`)));
  });

  it('el cliente crea la solicitud de SU cita pagada apuntando a la barbería de esa cita', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'appointments/apptR'), { clientId: CLIENT_UID, barbershopId: SHOP_ID, paid: true, status: 'accepted' });
    });
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    const base = { appointmentId: 'apptR', clientId: CLIENT_UID, status: 'pending', reason: 'No pude asistir', resolvedAt: null, resolvedBy: null };
    await assertFails(setDoc(doc(db, 'refundRequests/reqBad'), { ...base, barbershopId: 'shopAjena' }));
    await assertSucceeds(setDoc(doc(db, 'refundRequests/reqOk'), { ...base, barbershopId: SHOP_ID }));
  });

  it('nadie puede escribir directamente, ni siquiera el dueño "aprobándola" él mismo', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, `refundRequests/${REQUEST_ID}`), { status: 'approved' }));
  });

  describe('barbería que no puede operar (mora o sin aprobar)', () => {
    const day = 24 * 60 * 60 * 1000;
    const unpaid = () => ({ clientId: CLIENT_UID, barbershopId: SHOP_ID, barberId: BARBER_UID, status: 'pending', paid: false });

    async function seedShop(fields: Record<string, unknown>) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID, ...fields });
      });
    }

    it('una barbería inactiva no recibe citas', async () => {
      await seedShop({ active: false });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/a1'), unpaid()));
    });

    it('una barbería sin aprobar no recibe citas', async () => {
      await seedShop({ active: true, approvalStatus: 'pending' });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/a1'), unpaid()));
    });

    it('vencida pero dentro de la gracia sigue recibiendo citas', async () => {
      await seedShop({ active: true, approvalStatus: 'approved', paymentDueDate: Timestamp.fromMillis(Date.now() - 2 * day) });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'appointments/a1'), unpaid()));
    });

    it('con la gracia vencida (4 días por defecto) ya no recibe citas', async () => {
      await seedShop({ active: true, approvalStatus: 'approved', paymentDueDate: Timestamp.fromMillis(Date.now() - 6 * day) });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/a1'), unpaid()));
    });

    it('los días de gracia salen de la configuración del admin', async () => {
      await seedShop({ active: true, approvalStatus: 'approved', paymentDueDate: Timestamp.fromMillis(Date.now() - 6 * day) });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'platformSettings/main'), { graceDays: 10, monthlyFee: 50000 });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'appointments/a1'), unpaid()));
    });
  });
});
