import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, serverTimestamp, setDoc, Timestamp, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const OTHER_OWNER_UID = 'owner2';
const CLIENT_UID = 'client1';
const OTHER_CLIENT_UID = 'client2';
const BARBER_UID = 'barber1';
const CLOSURE_ID = 'closure1';

const hours = (n: number) => Timestamp.fromMillis(Date.now() + n * 3600 * 1000);

describe('firestore.rules — cierre de barbería (closure, avisos y reservas)', () => {
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
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow',
        active: true,
        approvalStatus: 'approved',
        paymentStatus: 'ok',
      });
      await setDoc(doc(db, 'barbershops/other'), { ownerId: OTHER_OWNER_UID, name: 'Otra', active: true, approvalStatus: 'approved' });
      for (const [uid, role] of [
        [OWNER_UID, 'owner'],
        [OTHER_OWNER_UID, 'owner'],
        [CLIENT_UID, 'client'],
        [OTHER_CLIENT_UID, 'client'],
      ]) {
        await setDoc(doc(db, `users/${uid}`), { role });
      }
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, 'appointments/appt1'), {
        clientId: CLIENT_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'accepted',
        paid: false,
        date: hours(5),
      });
      await setDoc(doc(db, 'purchases/buy1'), {
        buyerId: CLIENT_UID,
        barbershopId: SHOP_ID,
        status: 'pending_claim',
        items: [],
        totalAmount: 1000,
      });
      await setDoc(doc(db, `shopClosures/${CLOSURE_ID}`), {
        barbershopId: SHOP_ID,
        requestedBy: OWNER_UID,
        reason: 'Corte de luz',
        closedFrom: hours(-1),
        closedUntil: null,
        appointmentsAffected: 0,
      });
    });
  });

  const closureDoc = (extra: Record<string, unknown> = {}) => ({
    barbershopId: SHOP_ID,
    closedFrom: hours(1),
    closedUntil: hours(5),
    reason: 'Corte de luz',
    requestedBy: OWNER_UID,
    appointmentsAffected: 0,
    createdAt: serverTimestamp(),
    ...extra,
  });

  describe('shopClosures', () => {
    it('el dueño registra un cierre con fecha de regreso', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'shopClosures/c2'), closureDoc()));
    });

    it('el dueño registra un cierre SIN fecha de regreso (hasta nuevo aviso)', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'shopClosures/c3'), closureDoc({ closedUntil: null })));
    });

    it('un cierre cuyo final no es posterior al inicio se rechaza', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, 'shopClosures/c4'), closureDoc({ closedUntil: hours(0) })));
    });

    it('otro dueño no puede cerrar una barbería ajena', async () => {
      const db = testEnv.authenticatedContext(OTHER_OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, 'shopClosures/c5'), closureDoc({ requestedBy: OTHER_OWNER_UID })));
    });

    it('el dueño anota los conteos y que el cierre terminó, nada más', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(updateDoc(doc(db, `shopClosures/${CLOSURE_ID}`), { appointmentsAffected: 3, notificationsSent: 3 }));
      await assertSucceeds(updateDoc(doc(db, `shopClosures/${CLOSURE_ID}`), { appointmentsAffected: 3, endedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(db, `shopClosures/${CLOSURE_ID}`), { reason: 'otro motivo' }));
    });
  });

  describe('campo closure de la barbería', () => {
    it('el dueño marca y quita el cierre de su barbería', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(
        updateDoc(doc(db, `barbershops/${SHOP_ID}`), { closure: { closureId: 'c', from: hours(0), until: null, reason: 'x' } }),
      );
      await assertSucceeds(updateDoc(doc(db, `barbershops/${SHOP_ID}`), { closure: null }));
    });

    it('un cierre sin fecha de inicio se rechaza y un extraño no puede cerrar', async () => {
      const owner = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(updateDoc(doc(owner, `barbershops/${SHOP_ID}`), { closure: { reason: 'x' } }));
      const stranger = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(updateDoc(doc(stranger, `barbershops/${SHOP_ID}`), { closure: { from: hours(0), until: null } }));
    });
  });

  describe('avisos de cierre (notifications)', () => {
    const notice = (extra: Record<string, unknown> = {}) => ({
      toUserId: CLIENT_UID,
      title: 'BarberFlow cerró',
      body: 'Tu cita quedó aplazada.',
      type: 'shop_closure',
      read: false,
      createdAt: serverTimestamp(),
      barbershopId: SHOP_ID,
      closureId: CLOSURE_ID,
      relatedKind: 'appointment',
      relatedId: 'appt1',
      ...extra,
    });

    it('el dueño avisa al cliente de una cita de su barbería', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice()));
    });

    it('el dueño avisa al comprador de una compra abierta', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(
        setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_buy1`), notice({ relatedKind: 'purchase', relatedId: 'buy1' })),
      );
    });

    it('no puede avisar a alguien que no tiene esa cita', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice({ toUserId: OTHER_CLIENT_UID })));
    });

    it('el id debe ser el del cierre y la cita (no se inventan ni se repiten avisos)', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, 'notifications/cualquier-id'), notice()));
    });

    it('otro dueño no puede usar un cierre ni una cita que no son suyos', async () => {
      const db = testEnv.authenticatedContext(OTHER_OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice()));
    });

    it('un cliente no puede fabricar un aviso de cierre', async () => {
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice()));
    });

    it('el aviso no admite campos extra ni quedar leído de entrada', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice({ extra: 'x' })));
      await assertFails(setDoc(doc(db, `notifications/closure_${CLOSURE_ID}_appt1`), notice({ read: true })));
    });

    it('el dueño sigue sin poder mandar avisos manuales', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, 'notifications/n1'), { toUserId: CLIENT_UID, title: 'Hola', body: 'x', type: 'manual', read: false, createdAt: serverTimestamp() }));
    });
  });

  describe('reservas durante un cierre', () => {
    const appointment = (date: Timestamp) => ({
      clientId: CLIENT_UID,
      barbershopId: SHOP_ID,
      barberId: BARBER_UID,
      status: 'pending',
      paid: false,
      date,
    });

    it('sin cierre se reserva con normalidad', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), { closure: null });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'appointments/new1'), appointment(hours(24))));
    });

    it('con un cierre sin fecha de regreso NO se puede reservar hacia adelante', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), {
          closure: { closureId: CLOSURE_ID, from: hours(-1), until: null, reason: 'x' },
        });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/new2'), appointment(hours(24 * 10))));
    });

    it('con un cierre con fecha solo se bloquea esa ventana', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), {
          closure: { closureId: CLOSURE_ID, from: hours(10), until: hours(20), reason: 'x' },
        });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(setDoc(doc(db, 'appointments/new3'), appointment(hours(15))));
      await assertSucceeds(setDoc(doc(db, 'appointments/new4'), appointment(hours(30))));
      await assertSucceeds(setDoc(doc(db, 'appointments/new5'), appointment(hours(5))));
    });

    it('un cliente no puede reprogramar su cita pospuesta hacia una hora dentro del cierre', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'appointments/paid1'), {
          clientId: CLIENT_UID,
          barbershopId: SHOP_ID,
          barberId: BARBER_UID,
          status: 'postponed',
          paid: true,
          paymentId: 'pay1',
          date: hours(2),
          rescheduleHistory: [],
          forcedRatingPenalty: true,
        });
        await updateDoc(doc(db, `barbershops/${SHOP_ID}`), {
          closure: { closureId: CLOSURE_ID, from: hours(10), until: hours(20), reason: 'x' },
        });
      });
      const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
      await assertFails(updateDoc(doc(db, 'appointments/paid1'), { status: 'postponed', date: hours(15), rescheduleHistory: [] }));
      await assertSucceeds(updateDoc(doc(db, 'appointments/paid1'), { status: 'postponed', date: hours(30), rescheduleHistory: [] }));
    });
  });
});