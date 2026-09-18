import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

describe('firestore.rules — appointmentSlots/{id}', () => {
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

  it('nadie lee ni escribe directamente — solo el backend, vía transacción con Admin SDK', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertFails(setDoc(doc(db, 'appointmentSlots/barber1_2026-06-01T15:00'), { appointmentId: 'appt1' }));
    await assertFails(getDoc(doc(db, 'appointmentSlots/barber1_2026-06-01T15:00')));
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

  it('nadie puede escribir directamente, ni siquiera el dueño "aprobándola" él mismo', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, `refundRequests/${REQUEST_ID}`), { status: 'approved' }));
  });
});
