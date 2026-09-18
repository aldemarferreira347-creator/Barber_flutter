import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const BARBER_UID = 'barber1';

describe('firestore.rules — users/{uid} (awayUntilEstimate/awaySince)', () => {
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
      await setDoc(doc(context.firestore(), `users/${BARBER_UID}`), {
        role: 'barber',
        active: true,
        awayUntilEstimate: null,
        awaySince: null,
      });
    });
  });

  it('el barbero puede editar otros campos propios de su perfil', async () => {
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertSucceeds(updateDoc(doc(db, `users/${BARBER_UID}`), { name: 'Nuevo nombre' }));
  });

  it('el barbero NO puede marcar su propia ausencia editando el documento directamente', async () => {
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, `users/${BARBER_UID}`), { awayUntilEstimate: new Date(Date.now() + 30 * 60_000) }));
  });

  it('el barbero NO puede limpiar su propia ausencia editando el documento directamente', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${BARBER_UID}`), { awayUntilEstimate: new Date(), awaySince: new Date() });
    });
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, `users/${BARBER_UID}`), { awayUntilEstimate: null, awaySince: null }));
  });
});
