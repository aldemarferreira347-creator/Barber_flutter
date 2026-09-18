import { assertOwnerOfShop, assertStaffOfShop } from '../../src/shared/shopAuthorization';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
}));

beforeEach(() => fakeFirestore.reset());

describe('assertStaffOfShop', () => {
  it('permite al admin', async () => {
    fakeFirestore.seed('users/admin1', { role: 'admin' });
    await expect(assertStaffOfShop('admin1', 'shop1')).resolves.toBeUndefined();
  });

  it('permite al barbero de esa barbería', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
    await expect(assertStaffOfShop('barber1', 'shop1')).resolves.toBeUndefined();
  });

  it('rechaza al barbero de otra barbería', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'other-shop' });
    await expect(assertStaffOfShop('barber1', 'shop1')).rejects.toThrow('No tienes permiso');
  });

  it('permite al dueño de esa barbería', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    await expect(assertStaffOfShop('owner1', 'shop1')).resolves.toBeUndefined();
  });

  it('rechaza a un cliente', async () => {
    fakeFirestore.seed('users/client1', { role: 'client' });
    await expect(assertStaffOfShop('client1', 'shop1')).rejects.toThrow('No tienes permiso');
  });

  it('rechaza a un uid sin perfil', async () => {
    await expect(assertStaffOfShop('ghost', 'shop1')).rejects.toThrow('No se encontró tu perfil');
  });
});

describe('assertOwnerOfShop', () => {
  it('permite al admin', async () => {
    fakeFirestore.seed('users/admin1', { role: 'admin' });
    await expect(assertOwnerOfShop('admin1', 'shop1')).resolves.toBeUndefined();
  });

  it('permite al dueño de esa barbería', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    await expect(assertOwnerOfShop('owner1', 'shop1')).resolves.toBeUndefined();
  });

  it('rechaza al dueño de OTRA barbería', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'someone-else' });
    await expect(assertOwnerOfShop('owner1', 'shop1')).rejects.toThrow('Solo el dueño');
  });

  it('rechaza a un barbero de esa misma barbería (a propósito: solo el dueño aprueba reembolsos, spec 6.5)', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
    await expect(assertOwnerOfShop('barber1', 'shop1')).rejects.toThrow('Solo el dueño');
  });
});
