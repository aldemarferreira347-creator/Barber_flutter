import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc, writeBatch } from 'firebase/firestore';

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

  describe('pago Nequi manual', () => {
    const FLOW_ID = 'flow1';
    const PAYMENT_ID = 'payFlow';
    const inHours = (h: number) => Timestamp.fromMillis(Date.now() + h * 60 * 60 * 1000);

    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, `purchases/${FLOW_ID}`), {
          barbershopId: SHOP_ID,
          buyerId: BUYER_UID,
          items: [],
          totalAmount: 36000,
          status: 'pending_payment',
          paymentId: null,
          claimCode: null,
          claimedAt: null,
          expiresAt: null,
        });
        await setDoc(doc(db, `payments/${PAYMENT_ID}`), {
          payerId: BUYER_UID,
          amount: 36000,
          category: 'product',
          relatedId: FLOW_ID,
          status: 'pending',
          reference: 'M7654321',
          method: 'nequi',
        });
      });
    });

    it('el comprador enlaza su pago pendiente, pero sigue sin código', async () => {
      const db = testEnv.authenticatedContext(BUYER_UID).firestore();
      await assertSucceeds(updateDoc(doc(db, `purchases/${FLOW_ID}`), { paymentId: PAYMENT_ID }));
    });

    it('el comprador no puede enlazar un pago de otro monto, de otra compra o ya aprobado', async () => {
      const db = testEnv.authenticatedContext(BUYER_UID).firestore();
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const admin = context.firestore();
        await setDoc(doc(admin, 'payments/payBajo'), { payerId: BUYER_UID, amount: 100, category: 'product', relatedId: FLOW_ID, status: 'pending' });
        await setDoc(doc(admin, 'payments/payOtra'), { payerId: BUYER_UID, amount: 36000, category: 'product', relatedId: 'otra', status: 'pending' });
        await setDoc(doc(admin, 'payments/payOk'), { payerId: BUYER_UID, amount: 36000, category: 'product', relatedId: FLOW_ID, status: 'approved' });
      });
      for (const id of ['payBajo', 'payOtra', 'payOk']) {
        await assertFails(updateDoc(doc(db, `purchases/${FLOW_ID}`), { paymentId: id }));
      }
    });

    it('el comprador no puede darse a sí mismo el código ni pasar la compra a lista para reclamar', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `purchases/${FLOW_ID}`), { paymentId: PAYMENT_ID });
      });
      const db = testEnv.authenticatedContext(BUYER_UID).firestore();
      await assertFails(
        updateDoc(doc(db, `purchases/${FLOW_ID}`), { status: 'pending_claim', claimCode: 'ZZZZ9999', expiresAt: inHours(24) }),
      );
    });

    it('el personal confirma el pago y entrega el código en una sola escritura atómica', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `purchases/${FLOW_ID}`), { paymentId: PAYMENT_ID });
      });
      const db = testEnv.authenticatedContext(BARBER_UID).firestore();
      const batch = writeBatch(db);
      batch.update(doc(db, `payments/${PAYMENT_ID}`), { status: 'approved', resolvedAt: new Date(), resolvedBy: BARBER_UID });
      batch.update(doc(db, `purchases/${FLOW_ID}`), { status: 'pending_claim', claimCode: 'ABCD2345', expiresAt: inHours(24) });
      await assertSucceeds(batch.commit());
    });

    it('sin aprobar el pago en la misma escritura no hay código', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `purchases/${FLOW_ID}`), { paymentId: PAYMENT_ID });
      });
      const db = testEnv.authenticatedContext(BARBER_UID).firestore();
      await assertFails(updateDoc(doc(db, `purchases/${FLOW_ID}`), { status: 'pending_claim', claimCode: 'ABCD2345', expiresAt: inHours(24) }));
    });

    it('personal de otra barbería no puede confirmar ni rechazar', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), `purchases/${FLOW_ID}`), { paymentId: PAYMENT_ID });
      });
      const db = testEnv.authenticatedContext(OTHER_SHOP_BARBER_UID).firestore();
      await assertFails(updateDoc(doc(db, `purchases/${FLOW_ID}`), { status: 'payment_failed' }));
    });

    it('el personal rechaza el pago: la compra queda payment_failed', async () => {
      const db = testEnv.authenticatedContext(OWNER_UID).firestore();
      await assertSucceeds(updateDoc(doc(db, `purchases/${FLOW_ID}`), { status: 'payment_failed' }));
    });

    it('una compra vencida ya no se puede reclamar; una vigente sí', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await setDoc(doc(db, 'purchases/vencida'), { barbershopId: SHOP_ID, buyerId: BUYER_UID, status: 'pending_claim', claimCode: 'AAAA1111', expiresAt: inHours(-1) });
        await setDoc(doc(db, 'purchases/vigente'), { barbershopId: SHOP_ID, buyerId: BUYER_UID, status: 'pending_claim', claimCode: 'BBBB2222', expiresAt: inHours(5) });
      });
      const db = testEnv.authenticatedContext(BARBER_UID).firestore();
      await assertFails(updateDoc(doc(db, 'purchases/vencida'), { status: 'claimed', claimedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(db, 'purchases/vigente'), { status: 'claimed', claimedAt: serverTimestamp() }));
    });
  });
});
