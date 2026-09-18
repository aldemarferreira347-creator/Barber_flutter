import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const STRANGER_UID = 'stranger1';
const CLOSURE_ID = 'closure1';

describe('firestore.rules — shopClosures/{id}', () => {
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
      await setDoc(doc(db, `shopClosures/${CLOSURE_ID}`), { barbershopId: SHOP_ID, reason: 'Corte de energía' });
    });
  });

  it('el dueño de esa barbería puede leer el registro de cierre', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `shopClosures/${CLOSURE_ID}`)));
  });

  it('un desconocido no puede leerlo', async () => {
    const db = testEnv.authenticatedContext(STRANGER_UID).firestore();
    await assertFails(getDoc(doc(db, `shopClosures/${CLOSURE_ID}`)));
  });

  it('nadie escribe un cierre desde el cliente, ni el propio dueño', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, 'shopClosures/forged1'), { barbershopId: SHOP_ID, reason: 'x' }));
  });
});
