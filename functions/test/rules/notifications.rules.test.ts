import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const PROJECT_ID = 'demo-barber';
const RECIPIENT_UID = 'recipient1';
const OTHER_UID = 'stranger1';
const ADMIN_UID = 'admin1';
const NOTIFICATION_ID = 'notif1';

describe('firestore.rules — notifications/{id}', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `users/${RECIPIENT_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${OTHER_UID}`), { role: 'client', active: true });
      await setDoc(doc(db, `users/${ADMIN_UID}`), { role: 'admin', active: true });
      await setDoc(doc(db, `notifications/${NOTIFICATION_ID}`), {
        toUserId: RECIPIENT_UID,
        title: 'Hola',
        body: 'Cuerpo',
        type: 'manual',
        read: false,
      });
    });
  });

  it('el destinatario puede leer su propia notificación', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `notifications/${NOTIFICATION_ID}`)));
  });

  it('otro usuario no puede leer una notificación ajena', async () => {
    const db = testEnv.authenticatedContext(OTHER_UID).firestore();
    await assertFails(getDoc(doc(db, `notifications/${NOTIFICATION_ID}`)));
  });

  it('el admin puede leer cualquier notificación', async () => {
    const db = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertSucceeds(getDoc(doc(db, `notifications/${NOTIFICATION_ID}`)));
  });

  it('nadie puede crear una notificación desde el cliente, ni el propio admin', async () => {
    const asRecipient = testEnv.authenticatedContext(RECIPIENT_UID).firestore();
    await assertFails(
      setDoc(doc(asRecipient, 'notifications/forged1'), { toUserId: RECIPIENT_UID, title: 'x', body: 'y', type: 'manual', read: false }),
    );

    const asAdmin = testEnv.authenticatedContext(ADMIN_UID).firestore();
    await assertFails(
      setDoc(doc(asAdmin, 'notifications/forged2'), { toUserId: RECIPIENT_UID, title: 'x', body: 'y', type: 'manual', read: false }),
    );
  });

  it('el destinatario puede marcar su notificación como leída', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT_UID).firestore();
    await assertSucceeds(updateDoc(doc(db, `notifications/${NOTIFICATION_ID}`), { read: true }));
  });

  it('el destinatario no puede alterar el título ni el cuerpo al marcarla leída', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT_UID).firestore();
    await assertFails(updateDoc(doc(db, `notifications/${NOTIFICATION_ID}`), { read: true, title: 'Otro título' }));
  });

  it('otro usuario no puede marcar como leída una notificación ajena', async () => {
    const db = testEnv.authenticatedContext(OTHER_UID).firestore();
    await assertFails(updateDoc(doc(db, `notifications/${NOTIFICATION_ID}`), { read: true }));
  });

  it('nadie puede borrar una notificación', async () => {
    const db = testEnv.authenticatedContext(RECIPIENT_UID).firestore();
    await assertFails(deleteDoc(doc(db, `notifications/${NOTIFICATION_ID}`)));
  });
});
