import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const OWNER_UID = 'owner1';
const OTHER_UID = 'owner2';
const ADMIN_UID = 'admin1';

const draft = (overrides: Record<string, unknown> = {}) => ({
  ownerId: OWNER_UID,
  name: 'Sede Norte',
  address: 'Calle 1',
  ...overrides,
});

describe('firestore.rules — barbershopDrafts/{uid}_{n} (borradores sin pagar, máximo 5)', () => {
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
      await setDoc(doc(context.firestore(), `users/${ADMIN_UID}`), { role: 'admin' });
    });
  });

  it('el dueño puede crear borradores en sus cupos 1..5', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    for (let n = 1; n <= 5; n++) {
      await assertSucceeds(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_${n}`), draft()));
    }
  });

  it('no puede crear un sexto borrador: no existe el cupo 6 (ni ids arbitrarios)', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_6`), draft()));
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_0`), draft()));
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_11`), draft()));
    await assertFails(setDoc(doc(db, 'barbershopDrafts/cualquier-id'), draft()));
  });

  it('no puede crear borradores en los cupos de otra persona', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OTHER_UID}_1`), draft({ ownerId: OTHER_UID })));
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_1`), draft({ ownerId: OTHER_UID })));
  });

  it('un borrador no admite claves de más (ni estados de aprobación/pago)', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_1`), draft({ approvalStatus: 'approved' })));
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_1`), draft({ active: true })));
    await assertFails(setDoc(doc(db, `barbershopDrafts/${OWNER_UID}_1`), draft({ basura: 'x'.repeat(100) })));
  });

  it('solo su dueño (y el admin) lo lee; otro usuario no', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershopDrafts/${OWNER_UID}_1`), draft());
    });
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), `barbershopDrafts/${OWNER_UID}_1`)));
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(ADMIN_UID).firestore(), `barbershopDrafts/${OWNER_UID}_1`)));
    await assertFails(getDoc(doc(testEnv.authenticatedContext(OTHER_UID).firestore(), `barbershopDrafts/${OWNER_UID}_1`)));
  });

  it('el dueño edita y borra su borrador; otro usuario no puede', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershopDrafts/${OWNER_UID}_1`), draft());
    });
    const owner = testEnv.authenticatedContext(OWNER_UID).firestore();
    const other = testEnv.authenticatedContext(OTHER_UID).firestore();

    await assertFails(updateDoc(doc(other, `barbershopDrafts/${OWNER_UID}_1`), { name: 'Robado' }));
    await assertFails(deleteDoc(doc(other, `barbershopDrafts/${OWNER_UID}_1`)));

    await assertSucceeds(updateDoc(doc(owner, `barbershopDrafts/${OWNER_UID}_1`), { name: 'Sede Sur' }));
    await assertSucceeds(deleteDoc(doc(owner, `barbershopDrafts/${OWNER_UID}_1`)));
  });

  it('un borrador NO cuenta como barbería: nadie lo ve en barbershops', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershopDrafts/${OWNER_UID}_1`), draft());
    });
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    const shop = await getDoc(doc(db, `barbershops/${OWNER_UID}_1`));
    expect(shop.exists()).toBe(false);
  });
});
