import { readFileSync } from 'fs';
import { join } from 'path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

const PROJECT_ID = 'demo-barber';
const SHOP_ID = 'shop1';
const OWNER_UID = 'owner1';
const OTHER_UID = 'stranger1';

const image = new Uint8Array([0, 1, 2, 3]);

function fakeImageOfSize(bytes: number): Blob {
  return new Blob([new Uint8Array(bytes)], { type: 'image/png' });
}

describe('storage.rules — barbershops/{shopId}/services', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      storage: {
        rules: readFileSync(join(__dirname, '../../../storage.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 9199,
      },
      firestore: {
        rules: 'service cloud.firestore { match /databases/{db}/documents { match /{document=**} { allow read, write: if true; } } }',
        host: '127.0.0.1',
        port: 8080,
      },
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc(`barbershops/${SHOP_ID}`).set({ ownerId: OWNER_UID, name: 'Test Shop' });
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it('permite al dueño de la barbería subir una foto de servicio válida', async () => {
    const storage = testEnv.authenticatedContext(OWNER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/services/cut.png`);
    await assertSucceeds(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });

  it('rechaza la subida de un usuario que no es dueño de esa barbería', async () => {
    const storage = testEnv.authenticatedContext(OTHER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/services/cut.png`);
    await assertFails(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });

  it('rechaza la subida de un usuario no autenticado', async () => {
    const storage = testEnv.unauthenticatedContext().storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/services/cut.png`);
    await assertFails(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });

  it('rechaza un archivo que supera el límite de 5MB', async () => {
    const storage = testEnv.authenticatedContext(OWNER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/services/too_big.png`);
    await assertFails(uploadBytes(fileRef, fakeImageOfSize(6 * 1024 * 1024)));
  });

  it('permite a cualquier usuario autenticado leer una foto ya publicada', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const bucketRef = ref(context.storage(), `barbershops/${SHOP_ID}/services/existing.png`);
      await uploadBytes(bucketRef, image);
    });

    const storage = testEnv.authenticatedContext(OTHER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/services/existing.png`);
    await assertSucceeds(getBytes(fileRef));
  });

  it('deniega toda ruta que no tenga una regla explícita', async () => {
    const storage = testEnv.authenticatedContext(OWNER_UID).storage();
    const fileRef = ref(storage, 'random/unrelated/path.png');
    await assertFails(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });
});

describe('storage.rules — barbershops/{shopId}/products', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      storage: {
        rules: readFileSync(join(__dirname, '../../../storage.rules'), 'utf8'),
        host: '127.0.0.1',
        port: 9199,
      },
      firestore: {
        rules: 'service cloud.firestore { match /databases/{db}/documents { match /{document=**} { allow read, write: if true; } } }',
        host: '127.0.0.1',
        port: 8080,
      },
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc(`barbershops/${SHOP_ID}`).set({ ownerId: OWNER_UID, name: 'Test Shop' });
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  it('permite al dueño de la barbería subir una foto de producto válida', async () => {
    const storage = testEnv.authenticatedContext(OWNER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/products/wax.png`);
    await assertSucceeds(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });

  it('rechaza la subida de un usuario que no es dueño de esa barbería', async () => {
    const storage = testEnv.authenticatedContext(OTHER_UID).storage();
    const fileRef = ref(storage, `barbershops/${SHOP_ID}/products/wax.png`);
    await assertFails(uploadBytes(fileRef, fakeImageOfSize(1024)));
  });
});
