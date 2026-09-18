import { OwnershipService } from '../../src/barbershops/ownershipService';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  Timestamp: class FakeTimestamp {},
}));

beforeEach(() => fakeFirestore.reset());

describe('OwnershipService.requestOwnership', () => {
  it('promueve a un cliente a dueño cuando registra su barbería (spec 12.1)', async () => {
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'client1' });
    fakeFirestore.seed('users/client1', { role: 'client' });
    const service = new OwnershipService();

    await service.requestOwnership({ barbershopId: 'shop1', requestedBy: 'client1' });

    const user = (await fakeFirestore.doc('users/client1').get()).data()!;
    expect(user.role).toBe('owner');
  });

  it('es idempotente si ya es dueño de otra barbería (spec 12.2)', async () => {
    fakeFirestore.seed('barbershops/shop2', { ownerId: 'owner1' });
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    const service = new OwnershipService();

    await service.requestOwnership({ barbershopId: 'shop2', requestedBy: 'owner1' });

    const user = (await fakeFirestore.doc('users/owner1').get()).data()!;
    expect(user.role).toBe('owner');
  });

  it('no toca el rol de un admin', async () => {
    fakeFirestore.seed('barbershops/shop3', { ownerId: 'admin1' });
    fakeFirestore.seed('users/admin1', { role: 'admin' });
    const service = new OwnershipService();

    await service.requestOwnership({ barbershopId: 'shop3', requestedBy: 'admin1' });

    const user = (await fakeFirestore.doc('users/admin1').get()).data()!;
    expect(user.role).toBe('admin');
  });

  it('rechaza a quien no registró esa barbería', async () => {
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'client1' });
    fakeFirestore.seed('users/stranger1', { role: 'client' });
    const service = new OwnershipService();

    await expect(service.requestOwnership({ barbershopId: 'shop1', requestedBy: 'stranger1' })).rejects.toThrow('Solo quien registró');
  });

  it('rechaza una barbería inexistente', async () => {
    const service = new OwnershipService();
    await expect(service.requestOwnership({ barbershopId: 'ghost', requestedBy: 'client1' })).rejects.toThrow('no existe');
  });
});
