import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const BARBER_UID = 'barber1';
const CLIENT_UID = 'client1';
const STRANGER_UID = 'stranger1';
const APPOINTMENT_ID = 'appt1';

describe('firestore.rules — comments/{appointmentId}', () => {
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

  async function seed(status: 'published' | 'rejected') {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `barbershops/${SHOP_ID}`), { ownerId: OWNER_UID });
      await setDoc(doc(db, `users/${BARBER_UID}`), { role: 'barber', barbershopId: SHOP_ID });
      await setDoc(doc(db, `comments/${APPOINTMENT_ID}`), {
        appointmentId: APPOINTMENT_ID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        clientId: CLIENT_UID,
        text: 'Buen servicio',
        status,
      });
    });
  }

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it('un comentario publicado lo puede leer cualquier usuario autenticado', async () => {
    await seed('published');
    const db = testEnv.authenticatedContext(STRANGER_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `comments/${APPOINTMENT_ID}`)));
  });

  it('un comentario rechazado no lo puede leer un desconocido', async () => {
    await seed('rejected');
    const db = testEnv.authenticatedContext(STRANGER_UID).firestore();
    await assertFails(getDoc(doc(db, `comments/${APPOINTMENT_ID}`)));
  });

  it('el autor puede leer su propio comentario aunque esté rechazado', async () => {
    await seed('rejected');
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `comments/${APPOINTMENT_ID}`)));
  });

  it('el personal de esa barbería puede leer un comentario rechazado', async () => {
    await seed('rejected');
    const dbOwner = testEnv.authenticatedContext(OWNER_UID).firestore();
    await assertSucceeds(getDoc(doc(dbOwner, `comments/${APPOINTMENT_ID}`)));
    const dbBarber = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertSucceeds(getDoc(doc(dbBarber, `comments/${APPOINTMENT_ID}`)));
  });

  it('nadie escribe un comentario desde el cliente, ni el propio autor', async () => {
    await seed('published');
    const db = testEnv.authenticatedContext(CLIENT_UID).firestore();
    await assertFails(
      setDoc(doc(db, 'comments/forged1'), { appointmentId: 'forged1', clientId: CLIENT_UID, text: 'x', status: 'published' }),
    );
  });

  it('el barbero no puede escribir su propia respuesta editando el documento directamente', async () => {
    await seed('published');
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(
      setDoc(doc(db, `comments/${APPOINTMENT_ID}`), {
        appointmentId: APPOINTMENT_ID,
        barbershopId: SHOP_ID,
        barberId: BARBER_UID,
        clientId: CLIENT_UID,
        text: 'Buen servicio',
        status: 'published',
        replyText: 'Autorespuesta forjada',
      }),
    );
  });
});
