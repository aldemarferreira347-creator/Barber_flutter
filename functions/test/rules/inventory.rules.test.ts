import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc, writeBatch } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const BARBER_UID = 'barber1';
const OTHER_BARBER_UID = 'barber2';
const CLIENT_UID = 'client1';

describe('firestore.rules — inventario (stock y stockMovements)', () => {
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
      await setDoc(doc(db, `barbershops/other`), { ownerId: 'owner2', name: 'Otra' });
      await setDoc(doc(db, `users/${OWNER_UID}`), { role: 'owner' });
      await setDoc(doc(db, 'users/owner2'), { role: 'owner' });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, `users/${OTHER_BARBER_UID}`), { role: 'barber', barbershopId: 'other' });
      await setDoc(doc(db, `users/${CLIENT_UID}`), { role: 'client' });
      await setDoc(doc(db, `barbershops/${SHOP_ID}/products/p1`), { name: 'Cera', price: 15000, active: true, stock: 5 });
      await setDoc(doc(db, `barbershops/${SHOP_ID}/products/pNull`), { name: 'Gel', price: 9000, active: true, stock: null });
    });
  });

  const productPath = (id: string) => `barbershops/${SHOP_ID}/products/${id}`;
  const movementPath = (id: string) => `stockMovements/${id}`;

  function movement(uid: string, overrides: Record<string, unknown> = {}) {
    return {
      barbershopId: SHOP_ID,
      productId: 'p1',
      productName: 'Cera',
      type: 'out',
      quantity: 2,
      reason: 'sale',
      previousStock: 5,
      stockAfter: 3,
      byUserId: uid,
      byUserName: 'Beto',
      createdAt: serverTimestamp(),
      ...overrides,
    };
  }

  async function registerAs(uid: string, mov: Record<string, unknown>, stock: number, productId = 'p1') {
    const db = testEnv.authenticatedContext(uid).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, movementPath('m1')), mov);
    batch.update(doc(db, productPath(productId)), { stock, lastMovementId: 'm1' });
    return batch.commit();
  }

  it('el barbero de la barbería registra una salida y el stock baja', async () => {
    await assertSucceeds(registerAs(BARBER_UID, movement(BARBER_UID), 3));
  });

  it('el barbero registra una entrada y el stock sube', async () => {
    await assertSucceeds(registerAs(BARBER_UID, movement(BARBER_UID, { type: 'in', reason: 'restock', quantity: 4, stockAfter: 9 }), 9));
  });

  it('el dueño también registra movimientos', async () => {
    await assertSucceeds(registerAs(OWNER_UID, movement(OWNER_UID), 3));
  });

  it('un producto sin inventario empieza con una entrada desde cero', async () => {
    await assertSucceeds(
      registerAs(BARBER_UID, movement(BARBER_UID, { productId: 'pNull', type: 'in', reason: 'restock', quantity: 10, previousStock: 0, stockAfter: 10 }), 10, 'pNull'),
    );
  });

  it('el barbero NO puede cambiar el stock sin un movimiento que lo explique', async () => {
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, productPath('p1')), { stock: 99 }));
    await assertFails(updateDoc(doc(db, productPath('p1')), { stock: 99, lastMovementId: 'inventado' }));
  });

  it('el movimiento debe cuadrar con el stock del producto', async () => {
    // El producto queda en 4 pero el movimiento dice que quedó en 3.
    await assertFails(registerAs(BARBER_UID, movement(BARBER_UID), 4));
    // previousStock no coincide con el stock real (5).
    await assertFails(registerAs(BARBER_UID, movement(BARBER_UID, { previousStock: 8, stockAfter: 6 }), 6));
    // La salida no resta lo que dice.
    await assertFails(registerAs(BARBER_UID, movement(BARBER_UID, { stockAfter: 4 }), 4));
  });

  it('no deja el stock en negativo', async () => {
    await assertFails(registerAs(BARBER_UID, movement(BARBER_UID, { quantity: 9, stockAfter: -4 }), -4));
  });

  it('el movimiento no puede firmarse a nombre de otra persona', async () => {
    await assertFails(registerAs(BARBER_UID, movement(OWNER_UID), 3));
  });

  it('el barbero NO puede reutilizar un movimiento viejo para cambiar el stock sin dejar registro nuevo', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'stockMovements/viejo'), movement(BARBER_UID, { type: 'in', reason: 'restock', quantity: 45, previousStock: 5, stockAfter: 50, createdAt: Timestamp.now() }));
    });
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, productPath('p1')), { stock: 50, lastMovementId: 'viejo' }));
  });

  it('el barbero NO puede cambiar precio ni nombre del producto', async () => {
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, productPath('p1')), { price: 1 }));
    await assertFails(updateDoc(doc(db, productPath('p1')), { name: 'Otra cosa' }));
  });

  it('un barbero de OTRA barbería, un cliente y un anónimo no pueden mover el inventario', async () => {
    await assertFails(registerAs(OTHER_BARBER_UID, movement(OTHER_BARBER_UID), 3));
    await assertFails(registerAs(CLIENT_UID, movement(CLIENT_UID), 3));
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(anon, movementPath('m2')), movement('x')));
  });

  it('el dueño de OTRA barbería no toca ni el catálogo ni el inventario de esta', async () => {
    const db = testEnv.authenticatedContext('owner2').firestore();
    await assertFails(updateDoc(doc(db, productPath('p1')), { price: 1, name: 'x' }));
    await assertFails(updateDoc(doc(db, productPath('p1')), { stock: 50 }));
    await assertFails(registerAs('owner2', movement('owner2'), 3));
  });

  it('los movimientos solo los lee el personal de la barbería', async () => {
    await assertSucceeds(registerAs(BARBER_UID, movement(BARBER_UID), 3));
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(BARBER_UID).firestore(), movementPath('m1'))));
    await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(OWNER_UID).firestore(), movementPath('m1'))));
    await assertFails(getDoc(doc(testEnv.authenticatedContext(CLIENT_UID).firestore(), movementPath('m1'))));
  });

  it('un movimiento no se edita ni se borra', async () => {
    await assertSucceeds(registerAs(BARBER_UID, movement(BARBER_UID), 3));
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(updateDoc(doc(db, movementPath('m1')), { quantity: 1 }));
  });

  it('el stock del producto solo admite null o enteros no negativos', async () => {
    const db = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertFails(setDoc(doc(db, productPath('pBad')), { name: 'X', price: 1000, active: true, stock: -1 }));
    await assertFails(setDoc(doc(db, productPath('pBad2')), { name: 'X', price: 1000, active: true, stock: 1.5 }));
    await assertSucceeds(setDoc(doc(db, productPath('pOk')), { name: 'X', price: 1000, active: true, stock: 12 }));
    await assertSucceeds(setDoc(doc(db, productPath('pOk2')), { name: 'X', price: 1000, active: true, stock: null }));
  });
});
