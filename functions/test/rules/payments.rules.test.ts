import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const PAYER_UID = 'payer1';
const OTHER_UID = 'stranger1';
const ADMIN_UID = 'admin1';
const PAYMENT_ID = 'payment1';

describe('firestore.rules — payments/{id}', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `users/${PAYER_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${OTHER_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin', active: true });
      await setDoc(doc(db, `payments/${PAYMENT_ID}`), {
        payerId: PAYER_UID,
        amount: 20000,
        category: 'appointment',
        relatedId: 'appt1',
        status: 'approved',
      });
    });
  });

  it('el pagador puede leer su propio pago', async () => {
    const db = testEnv.authenticatedContext(PAYER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `payments/${PAYMENT_ID}`)));
  });

  it('otro usuario no puede leer un pago ajeno', async () => {
    const db = testEnv.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(db, `payments/${PAYMENT_ID}`)));
  });

  it('el admin puede leer cualquier pago', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `payments/${PAYMENT_ID}`)));
  });

  it('nadie puede crear un pago desde el cliente, ni el propio pagador', async () => {
    const db = testEnv.authenticatedContext(PAYER_UID).firestore();
    await assertFails(
      setDoc(doc(db, 'payments/forged1'), { payerId: PAYER_UID, amount: 1, category: 'appointment', relatedId: 'x', status: 'approved' }),
    );
  });

  it('nadie puede alterar el estado o el monto de un pago desde el cliente', async () => {
    const asPayer = testEnv.authenticatedContext(PAYER_UID).firestore();
    await assertFails(updateDoc(doc(asPayer, `payments/${PAYMENT_ID}`), { status: 'refunded' }));

    const asAdmin = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertFails(updateDoc(doc(asAdmin, `payments/${PAYMENT_ID}`), { amount: 1 }));
  });
});
