import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const CLIENT_UID = 'client1';
const APPOINTMENT_ID = 'appt1';

describe('firestore.rules — ratings/{appointmentId}', () => {
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
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID, ratingSum: 4, ratingCount: 1 });
      await setDoc(doc(db, `ratings/${APPOINTMENT_ID}`), {
        appointmentId: APPOINTMENT_ID,
        barbershopId: SHOP_ID,
        clientId: CLIENT_UID,
        barberStars: 5,
        shopStars: 4,
      });
    });
  });

  it('cualquier usuario autenticado puede leer las calificaciones', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `ratings/${APPOINTMENT_ID}`)));
    const db2 = testEnv.authenticatedContext('otro-usuario').firestore();
    await assertSucceeds(getDoc(doc(db2, `ratings/${APPOINTMENT_ID}`)));
  });

  it('ni el propio cliente puede escribir una calificación directamente (solo el backend)', async () => {
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertFails(setDoc(doc(db, 'ratings/forged1'), { appointmentId: 'forged1', clientId: CLIENT_UID, barberStars: 5, shopStars: 5 }));
  });

  it('el dueño no puede inflar el promedio de su barbería editando el documento', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID, ratingSum: 999, ratingCount: 1 }));
  });
});
