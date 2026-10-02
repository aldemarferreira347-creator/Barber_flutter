import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, setDoc } from 'firebase/firestore';

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

  // Registrar exige pagar primero: el payments/{id} referenciado debe ser del
  // dueño, categoría 'subscription', aprobado y apuntar a ESTE id de barbería.
  async function seedPayment(id: string, overrides: Record<string, unknown> = {}) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `payments/${id}`), {
        payerId: OWNER_UID,
        category: 'subscription',
        relatedId: SHOP_ID,
        status: 'approved',
        ...overrides,
      });
    });
  }

  const newShop = (overrides: Record<string, unknown> = {}) => ({
    ownerId: OWNER_UID,
    name: 'BarberFlow Centro',
    approvalStatus: 'pending',
    active: false,
    paymentStatus: 'ok',
    paymentId: 'pay1',
    ...overrides,
  });

  it('puede registrar una barbería SOLO con un pago aprobado, y nace pendiente e inactiva', async () => {
    await seedPayment('pay1');
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop()));
  });

  it('no puede registrarla sin pago', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    const withoutPayment: Record<string, unknown> = { ...newShop() };
    delete withoutPayment.paymentId;
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), withoutPayment));
  });

  it('no sirve un pago inexistente, sin aprobar, ajeno, de otra categoría o de otra barbería', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ paymentId: 'no-existe' })));

    await seedPayment('pending', { status: 'pending' });
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ paymentId: 'pending' })));

    await seedPayment('ajeno', { payerId: 'otro-usuario' });
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ paymentId: 'ajeno' })));

    await seedPayment('producto', { category: 'product' });
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ paymentId: 'producto' })));

    await seedPayment('otra-barberia', { relatedId: 'otra-barberia-id' });
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ paymentId: 'otra-barberia' })));
  });

  it('no puede nacer ya activa', async () => {
    await seedPayment('pay1');
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ active: true })));
  });

  it('no puede nacer ya aprobada', async () => {
    await seedPayment('pay1');
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, `barbershops/${SHOP_ID}`), newShop({ approvalStatus: 'approved' })));
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

  describe('borrar la barbería (Delete del CRUD del dueño)', () => {
    async function seedShop(fields: Record<string, unknown>) {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), `barbershops/${SHOP_ID}`), {
          ownerId: OWNER_UID,
          name: 'BarberFlow Centro',
          active: false,
          paymentStatus: 'ok',
          ...fields,
        });
      });
    }

    it('el dueño borra una barbería pendiente o rechazada', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await seedShop({ approvalStatus: 'pending' });
      await assertSucceeds(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
      await seedShop({ approvalStatus: 'rejected' });
      await assertSucceeds(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
    });

    it('el dueño NO borra una barbería aprobada y vigente', async () => {
      await seedShop({ approvalStatus: 'approved', active: true });
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
    });

    it('el dueño sí la borra una vez cancelada la membresía (bloqueada)', async () => {
      await seedShop({ approvalStatus: 'approved', paymentStatus: 'blocked' });
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
    });

    it('otro usuario nunca borra la barbería ajena, aunque esté pendiente', async () => {
      await seedShop({ approvalStatus: 'pending' });
      const db = testEnv.authenticatedContext('intruso').firestore();
      await assertFails(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
    });

    it('el admin borra cualquiera', async () => {
      await seedShop({ approvalStatus: 'approved', active: true });
      const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
      await assertSucceeds(deleteDoc(doc(db, `barbershops/${SHOP_ID}`)));
    });
  });
});
