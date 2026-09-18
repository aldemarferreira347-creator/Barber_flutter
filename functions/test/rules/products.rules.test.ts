import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const OTHER_UID = 'stranger1';
const ADMIN_UID = 'admin1';

describe('firestore.rules — barbershops/{shopId}/products', () => {
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
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID, name: 'Test Shop' });
      await setDoc(doc(db, `users/${OWNER_UID}`), { role: 'owner' });
      await setDoc(doc(db, `users/${OTHER_UID}`), { role: 'client' });
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin' });
    });
  });

  it('el dueño de la barbería puede crear un producto', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(setDoc(doc(db, `barbershops/${SHOP_ID}/products/p1`), { name: 'Cera', price: 15000, active: true }));
  });

  it('un usuario que no es dueño de esa barbería no puede crear un producto', async () => {
    const db = testEnv.authenticatedContext(OTHER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}/products/p1`), { name: 'Cera', price: 15000, active: true }));
  });

  it('el admin puede escribir productos de cualquier barbería', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertSucceeds(setDoc(doc(db, `barbershops/${SHOP_ID}/products/p1`), { name: 'Cera', price: 15000, active: true }));
  });

  it('cualquier usuario autenticado puede leer el catálogo', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershops/${SHOP_ID}/products/p1`), { name: 'Cera', price: 15000, active: true });
    });
    const db = testEnv.authenticatedContext(OTHER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `barbershops/${SHOP_ID}/products/p1`)));
  });
});
