import { readFileSync } from 'fs';
import { join } from 'path';

import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, limit, query, setDoc, updateDoc, where } from 'firebase/firestore';

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

  it('el barbero puede marcar su regreso limpiando AMBOS campos de ausencia (markBarberReturned)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${BARBER_UID}`), { awayUntilEstimate: new Date(), awaySince: new Date() });
    });
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertSucceeds(updateDoc(doc(db, `users/${BARBER_UID}`), { awayUntilEstimate: null, awaySince: null }));
  });

  it('el barbero NO puede limpiar solo uno de los dos campos de ausencia', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${BARBER_UID}`), { awayUntilEstimate: new Date(), awaySince: new Date() });
    });
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, `users/${BARBER_UID}`), { awayUntilEstimate: null }));
  });

  it('el barbero NO puede cambiarse a sí mismo de barbería (escalada de privilegios)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${BARBER_UID}`), { barbershopId: 'shopA' });
    });
    const db = testEnv.authenticatedContext(BARBER_UID).firestore();
    await assertFails(updateDoc(doc(db, `users/${BARBER_UID}`), { barbershopId: 'shopB' }));
  });

  it('un cliente NO puede asignarse barbershopId ni rol barbero editando su perfil', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users/client1'), { role: 'client', active: true, barbershopId: null });
    });
    const db = testEnv.authenticatedContext('client1').firestore();
    await assertFails(updateDoc(doc(db, 'users/client1'), { barbershopId: 'shopB' }));
    await assertFails(updateDoc(doc(db, 'users/client1'), { role: 'barber', barbershopId: 'shopB' }));
  });

  it('el autorregistro NO puede traer calificación, ausencia ni barbería precargadas', async () => {
    const db = testEnv.authenticatedContext('nuevo1').firestore();
    await assertFails(setDoc(doc(db, 'users/nuevo1'), { role: 'client', active: true, ratingSum: 5000, ratingCount: 1000 }));
    await assertFails(setDoc(doc(db, 'users/nuevo1'), { role: 'client', active: true, barbershopId: 'shopA' }));
    await assertSucceeds(setDoc(doc(db, 'users/nuevo1'), { role: 'client', active: true, name: 'Nuevo', barbershopId: null }));
  });

  describe('contratar / dar de baja barberos (dueño)', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const fs = context.firestore();
        await setDoc(doc(fs, 'barbershops/shopA'), { ownerId: 'owner1', approvalStatus: 'approved', active: true });
        await setDoc(doc(fs, 'users/owner1'), { role: 'owner', active: true });
        await setDoc(doc(fs, 'users/client2'), { role: 'client', active: true, email: 'c2@x.com', phone: '300', barbershopId: null });
      });
    });

    it('el dueño contrata a un cliente solo tocando role y barbershopId', async () => {
      const db = testEnv.authenticatedContext('owner1').firestore();
      await assertSucceeds(updateDoc(doc(db, 'users/client2'), { role: 'barber', barbershopId: 'shopA' }));
    });

    it('el dueño NO puede alterar otros datos del cliente al contratarlo', async () => {
      const db = testEnv.authenticatedContext('owner1').firestore();
      await assertFails(updateDoc(doc(db, 'users/client2'), { role: 'barber', barbershopId: 'shopA', email: 'otro@x.com' }));
    });

    it('el dueño NO puede contratar hacia una barbería ajena', async () => {
      const db = testEnv.authenticatedContext('owner1').firestore();
      await assertFails(updateDoc(doc(db, 'users/client2'), { role: 'barber', barbershopId: 'shopZ' }));
    });

    it('el dueño da de baja a su barbero solo tocando role y barbershopId', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await updateDoc(doc(context.firestore(), 'users/client2'), { role: 'barber', barbershopId: 'shopA' });
      });
      const db = testEnv.authenticatedContext('owner1').firestore();
      await assertFails(updateDoc(doc(db, 'users/client2'), { role: 'client', barbershopId: null, phone: '999' }));
      await assertSucceeds(updateDoc(doc(db, 'users/client2'), { role: 'client', barbershopId: null }));
    });
  });

  describe('lectura de perfiles ajenos (privacidad de email/teléfono)', () => {
    beforeEach(async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const fs = context.firestore();
        await setDoc(doc(fs, 'users/clientA'), { role: 'client', active: true, email: 'a@x.com', phone: '300' });
        await setDoc(doc(fs, 'users/clientB'), { role: 'client', active: true, email: 'b@x.com', phone: '301' });
        await setDoc(doc(fs, 'users/ownerX'), { role: 'owner', active: true });
        await setDoc(doc(fs, 'users/adminX'), { role: 'admin', active: true });
      });
    });

    it('un cliente NO puede leer el perfil de otro cliente (ni consultarlos por correo)', async () => {
      const db = testEnv.authenticatedContext('clientB').firestore();
      await assertFails(getDoc(doc(db, 'users/clientA')));
      await assertFails(getDocs(query(collection(db, 'users'), where('email', '==', 'a@x.com'), where('role', '==', 'client'))));
    });

    it('un cliente sí lee su propio perfil y el de un barbero (para elegir con quién agendar)', async () => {
      const db = testEnv.authenticatedContext('clientB').firestore();
      await assertSucceeds(getDoc(doc(db, 'users/clientB')));
      await assertSucceeds(getDoc(doc(db, `users/${BARBER_UID}`)));
    });

    it('un dueño busca clientes por correo para contratarlos; el admin lee a todos', async () => {
      const owner = testEnv.authenticatedContext('ownerX').firestore();
      await assertSucceeds(getDocs(query(collection(owner, 'users'), where('email', '==', 'a@x.com'), where('role', '==', 'client'), limit(1))));
      const admin = testEnv.authenticatedContext('adminX').firestore();
      await assertSucceeds(getDoc(doc(admin, 'users/clientA')));
    });
  });
});
