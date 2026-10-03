import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const settings = (overrides: Record<string, unknown> = {}) => ({
  nequiPhone: '3001234567',
  nequiHolder: 'BarberFlow SAS',
  monthlyFee: 60000,
  graceDays: 5,
  ...overrides,
});

describe('firestore.rules — platformSettings/main', () => {
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
      await setDoc(doc(db, 'users/admin1'), { role: 'admin' });
      await setDoc(doc(db, 'users/owner1'), { role: 'owner' });
      await setDoc(doc(db, 'platformSettings/main'), settings());
    });
  });

  it('cualquier usuario autenticado lee los datos de cobro (el dueño necesita el Nequi)', async () => {
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext('owner1').firestore(), 'platformSettings/main')));
    await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'platformSettings/main')));
  });

  it('solo el admin los escribe', async () => {
    await assertFails(setDoc(doc(testEnv.authenticatedContext('owner1').firestore(), 'platformSettings/main'), settings({ nequiPhone: '3009999999' })));
    await assertSucceeds(setDoc(doc(testEnv.authenticatedContext('admin1').firestore(), 'platformSettings/main'), settings({ nequiPhone: '3009999999' })));
  });

  it('el admin no puede guardar un Nequi inválido, una tarifa no positiva ni otro documento', async () => {
    const db = testEnv.authenticatedContext('admin1').firestore();
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ nequiPhone: '12345' })));
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ nequiPhone: '2001234567' })));
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ monthlyFee: 0 })));
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ graceDays: -1 })));
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ graceDays: 90 })));
    await assertFails(setDoc(doc(db, 'platformSettings/main'), settings({ extra: true })));
    await assertFails(setDoc(doc(db, 'platformSettings/otro'), settings()));
  });
});
