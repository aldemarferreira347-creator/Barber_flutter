import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const ADMIN_UID = 'admin1';

describe('firestore.rules — barbershops/{id} (spec 12.1: aprobación del admin)', () => {
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
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin' });
    });
  });

  it('el cliente puede registrar una barbería, pero nace pendiente e inactiva', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'pending',
        active: false,
      }),
    );
  });

  it('no puede nacer ya activa', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'pending',
        active: true,
      }),
    );
  });

  it('no puede nacer ya aprobada', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'approved',
        active: false,
      }),
    );
  });

  it('el dueño no puede aprobarse a sí mismo editando el documento', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'pending',
        active: false,
        paymentStatus: 'ok',
      });
    });
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(
      setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'approved',
        active: true,
        paymentStatus: 'ok',
      }),
    );
  });

  it('el admin sí puede aprobar la barbería', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'pending',
        active: false,
        paymentStatus: 'ok',
      });
    });
    const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertSucceeds(
      setDoc(doc(db, `barbershops/${SHOP_ID}`), {
        ownerId: OWNER_UID,
        name: 'BarberFlow Centro',
        approvalStatus: 'approved',
        active: true,
        paymentStatus: 'ok',
        paymentDueDate: new Date(),
      }),
    );
  });
});
