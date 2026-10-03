import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const PAYER_UID = 'payer1';
const OTHER_UID = 'stranger1';
const ADMIN_UID = 'admin1';
const OWNER_UID = 'owner1';
const BARBER_UID = 'barber1';
const OTHER_BARBER_UID = 'barber2';
const SHOP_ID = 'shop1';
const OTHER_SHOP_ID = 'shop2';

// Pago Nequi manual: nace 'pending' con la referencia del comprobante; solo
// quien recibe el dinero (personal de la barbería, o el admin para la
// mensualidad) lo confirma.
const newPayment = (overrides: Record<string, unknown> = {}) => ({
  payerId: PAYER_UID,
  amount: 20000,
  category: 'appointment',
  relatedId: 'appt1',
  description: 'Cita',
  status: 'pending',
  createdAt: serverTimestamp(),
  resolvedAt: null,
  refundedAmount: null,
  reference: 'M1234567',
  method: 'nequi',
  ...overrides,
});

describe('firestore.rules — payments/{id} (Nequi manual)', () => {
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
      await setDoc(doc(db, `users/${PAYER_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${OTHER_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin', active: true });
      await setDoc(doc(db, `users/${OWNER_UID}`), { role: 'owner', active: true });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, `users/${OTHER_BARBER_UID}`), { role: 'barber', barbershopId: OTHER_SHOP_ID });
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID });
      await setDoc(doc(db, `barbershops/${OTHER_SHOP_ID}`), { ownerId: 'owner2' });
      await setDoc(doc(db, 'appointments/appt1'), {
        clientId: PAYER_UID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        status: 'pending',
        paid: true,
        paymentId: 'pay1',
        servicePrice: 20000,
      });
      await setDoc(doc(db, 'purchases/purchase1'), {
        barbershopId: SHOP_ID,
        buyerId: PAYER_UID,
        status: 'pending_payment',
        totalAmount: 36000,
        paymentId: 'payProd',
      });
      await setDoc(doc(db, 'payments/pay1'), { ...newPayment(), createdAt: new Date() });
      await setDoc(doc(db, 'payments/payProd'), {
        ...newPayment({ amount: 36000, category: 'product', relatedId: 'purchase1' }),
        createdAt: new Date(),
      });
      await setDoc(doc(db, 'payments/paySub'), {
        ...newPayment({ payerId: OWNER_UID, amount: 50000, category: 'subscription', relatedId: SHOP_ID }),
        createdAt: new Date(),
      });
    });
  });

  describe('lectura', () => {
    it('el pagador, el personal de la barbería de la cita y el admin pueden leerlo', async () => {
      for (const uid of [PAYER_UID, OWNER_UID, BARBER_UID, ADMIN_UID]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        await assertSucceeds(getDoc(doc(db, 'payments/pay1')));
      }
    });

    it('un desconocido o personal de OTRA barbería no puede leerlo', async () => {
      for (const uid of [OTHER_UID, OTHER_BARBER_UID]) {
        const db = testEnv.authenticatedContext(uid).firestore();
        await assertFails(getDoc(doc(db, 'payments/pay1')));
      }
    });

    it('la mensualidad solo la leen su dueño (pagador) y el admin, no los barberos', async () => {
      await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/paySub')));
      await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(ADMIN_UID).firestore(), 'payments/paySub')));
      await assertFails(getDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), 'payments/paySub')));
    });
  });

  describe('creación', () => {
    it('el pagador registra un pago pendiente con su referencia', async () => {
      const db = testEnv.authenticatedContext(PAYER_UID).firestore();
      await assertSucceeds(setDoc(doc(db, 'payments/new1'), newPayment()));
    });

    it('nadie puede fabricar un pago ya aprobado, ni a nombre de otro, ni sin referencia válida', async () => {
      const db = testEnv.authenticatedContext(PAYER_UID).firestore();
      await assertFails(setDoc(doc(db, 'payments/f1'), newPayment({ status: 'approved' })));
      await assertFails(setDoc(doc(db, 'payments/f2'), newPayment({ payerId: OTHER_UID })));
      const withoutReference: Record<string, unknown> = newPayment();
      delete withoutReference.reference;
      await assertFails(setDoc(doc(db, 'payments/f3'), withoutReference));
      await assertFails(setDoc(doc(db, 'payments/f4'), newPayment({ reference: 'ab' })));
      await assertFails(setDoc(doc(db, 'payments/f5'), newPayment({ reference: 'con espacios y <script>' })));
      await assertFails(setDoc(doc(db, 'payments/f6'), newPayment({ amount: 0 })));
      await assertFails(setDoc(doc(db, 'payments/f7'), newPayment({ amount: -5 })));
      await assertFails(setDoc(doc(db, 'payments/f8'), newPayment({ method: 'cash' })));
      await assertFails(setDoc(doc(db, 'payments/f9'), newPayment({ category: 'otra' })));
      await assertFails(setDoc(doc(db, 'payments/f10'), newPayment({ extra: 'campo no permitido' })));
    });

    it('la mensualidad solo se acepta por el valor vigente (50000 por defecto)', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(setDoc(doc(db, 'payments/s1'), newPayment({ payerId: OWNER_UID, category: 'subscription', amount: 100 })));
      await assertSucceeds(setDoc(doc(db, 'payments/s2'), newPayment({ payerId: OWNER_UID, category: 'subscription', amount: 50000 })));

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(doc(context.firestore(), 'platformSettings/main'), { monthlyFee: 80000 });
      });
      await assertFails(setDoc(doc(db, 'payments/s3'), newPayment({ payerId: OWNER_UID, category: 'subscription', amount: 50000 })));
      await assertSucceeds(setDoc(doc(db, 'payments/s4'), newPayment({ payerId: OWNER_UID, category: 'subscription', amount: 80000 })));
    });
  });

  describe('confirmación', () => {
    const resolve = (status: string, uid: string) => ({ status, resolvedAt: new Date(), resolvedBy: uid });

    it('el pagador NO puede aprobar su propio pago', async () => {
      const db = testEnv.authenticatedContext(PAYER_UID).firestore();
      await assertFails(updateDoc(doc(db, 'payments/pay1'), resolve('approved', PAYER_UID)));
      await assertFails(updateDoc(doc(db, 'payments/pay1'), { status: 'approved', resolvedAt: new Date() }));
    });

    it('el pagador sí puede retirar su pago pendiente (rechazarlo)', async () => {
      const db = testEnv.authenticatedContext(PAYER_UID).firestore();
      await assertSucceeds(updateDoc(doc(db, 'payments/pay1'), { status: 'rejected', resolvedAt: new Date() }));
    });

    it('el dueño y el barbero de ESA barbería confirman el pago de una cita', async () => {
      await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/pay1'), resolve('approved', OWNER_UID)));
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'payments/pay1'), { status: 'pending' });
      });
      await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), 'payments/pay1'), resolve('approved', BARBER_UID)));
    });

    it('personal de OTRA barbería o un desconocido no confirma', async () => {
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(OTHER_BARBER_UID).firestore(), 'payments/pay1'), resolve('approved', OTHER_BARBER_UID)));
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(OTHER_UID).firestore(), 'payments/pay1'), resolve('approved', OTHER_UID)));
    });

    it('quien confirma debe firmar con su propio uid y no puede tocar el monto', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertFails(updateDoc(doc(db, 'payments/pay1'), resolve('approved', 'otro-uid')));
      await assertFails(updateDoc(doc(db, 'payments/pay1'), { ...resolve('approved', OWNER_UID), amount: 1 }));
    });

    it('un pago ya resuelto no vuelve a cambiar de estado', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await updateDoc(doc(db, 'payments/pay1'), resolve('approved', OWNER_UID));
      await assertFails(updateDoc(doc(db, 'payments/pay1'), resolve('rejected', OWNER_UID)));
    });

    it('el pago de un producto lo confirma el personal de la barbería de la compra', async () => {
      await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), 'payments/payProd'), resolve('approved', BARBER_UID)));
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(OTHER_BARBER_UID).firestore(), 'payments/payProd'), resolve('approved', OTHER_BARBER_UID)));
    });

    it('la mensualidad solo la confirma el admin: ni su dueño ni los barberos', async () => {
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/paySub'), resolve('approved', OWNER_UID)));
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), 'payments/paySub'), resolve('approved', BARBER_UID)));
      await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(ADMIN_UID).firestore(), 'payments/paySub'), resolve('approved', ADMIN_UID)));
    });

    it('confirmar el pago de una cita y aceptarla va en una sola escritura atómica', async () => {
      const db = testEnv.authenticatedContext(BARBER_UID).firestore();
      const batch = writeBatch(db);
      batch.update(doc(db, 'payments/pay1'), resolve('approved', BARBER_UID));
      batch.update(doc(db, 'appointments/appt1'), { status: 'accepted' });
      await assertSucceeds(batch.commit());
    });

    it('no se acepta una cita pagada mientras su pago siga sin verificar', async () => {
      const db = testEnv.authenticatedContext(BARBER_UID).firestore();
      await assertFails(updateDoc(doc(db, 'appointments/appt1'), { status: 'accepted' }));
    });
  });

  describe('reembolso', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'payments/pay1'), { status: 'approved' });
      });
    });

    it('el dueño reembolsa indicando el medio; el barbero y el pagador no', async () => {
      const refund = { status: 'refunded', refundedAmount: 20000, refundMethod: 'cash', resolvedAt: new Date() };
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(PAYER_UID).firestore(), 'payments/pay1'), refund));
      await assertFails(updateDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), 'payments/pay1'), refund));
      await assertFails(
        updateDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/pay1'), { ...refund, refundMethod: 'bitcoin' }),
      );
      await assertFails(
        updateDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/pay1'), { ...refund, refundedAmount: 99999 }),
      );
      await assertSucceeds(updateDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), 'payments/pay1'), refund));
    });
  });
});
