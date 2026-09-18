import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OTHER_SHOP_ID = 'shop2';
const OWNER_UID = 'owner1';
const BARBER_UID = 'barber1';
const OTHER_SHOP_BARBER_UID = 'barber2';
const BUYER_UID = 'buyer1';
const STRANGER_UID = 'stranger1';
const ADMIN_UID = 'admin1';
const PURCHASE_ID = 'purchase1';

describe('firestore.rules — purchases/{id}', () => {
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
      await setDoc(doc(db, `users/${OWNER_UID}`), { role: 'owner' });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, `users/${OTHER_SHOP_BARBER_UID}`), { role: 'barber', barbershopId: OTHER_SHOP_ID });
      await setDoc(doc(db, `users/${BUYER_UID}`), { role: 'client' });
      await setDoc(doc(db, `users/${STRANGER_UID}`), { role: 'client' });
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin' });
      await setDoc(doc(db, `purchases/${PURCHASE_ID}`), {
        barbershopId: SHOP_ID,
        buyerId: BUYER_UID,
        items: [],
        totalAmount: 15000,
        status: 'pending_claim',
        claimCode: 'ABCD1234',
      });
    });
  });

  it('el comprador puede leer su propia compra', async () => {
    const db = testEnv.authenticatedContext(BUYER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('el dueño de esa barbería puede leerla', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('un barbero de esa barbería puede leerla', async () => {
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('un barbero de OTRA barbería no puede leerla', async () => {
    const db = testEnv.authenticatedContext(OTHER_SHOP_BARBER_UID).firestore();
    await assertFails(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('un desconocido no puede leerla', async () => {
    const db = testEnv.authenticatedContext(STRANGER_UID).firestore();
    await assertFails(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('el admin puede leer cualquier compra', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `purchases/${PURCHASE_ID}`)));
  });

  it('nadie escribe una compra desde el cliente, ni el comprador ni el barbero de esa barbería', async () => {
    const asBuyer = testEnv.authenticatedContext(BUYER_UID).firestore();
    await assertFails(updateDoc(doc(asBuyer, `purchases/${PURCHASE_ID}`), { status: 'claimed' }));

    const asBarber = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(asBarber, `purchases/${PURCHASE_ID}`), { status: 'claimed' }));

    const asOwner = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(asOwner, 'purchases/forged1'), { barbershopId: SHOP_ID, buyerId: BUYER_UID, status: 'claimed' }));
  });
});
