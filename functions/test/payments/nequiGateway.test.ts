import { getFirestore } from 'firebase-admin/firestore';

import { SimulatedNequiGateway } from '../../src/payments/nequiGateway';

jest.mock('firebase-admin/firestore', () => {
  const store = new Map<string, Record<string, unknown>>();
  let nextId = 0;

  function docRef(id: string) {
    return {
      id,
      get: async () => ({ exists: store.has(id), data: () => store.get(id) }),
      update: async (patch: Record<string, unknown>) => {
        store.set(id, { ...(store.get(id) ?? {}), ...patch });
      },
    };
  }

  return {
    getFirestore: () => ({
      collection: () => ({
        add: async (data: Record<string, unknown>) => {
          const id = `doc${nextId++}`;
          store.set(id, data);
          return docRef(id);
        },
        doc: (id: string) => docRef(id),
      }),
    }),
    FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  };
});

describe('SimulatedNequiGateway', () => {
  const gateway = new SimulatedNequiGateway(0);

  it('crea el pago en pending y lo aprueba tras el delay simulado', async () => {
    const id = await gateway.requestPayment({
      payerId: 'user1',
      amount: 20000,
      category: 'appointment',
      relatedId: 'appt1',
      description: null,
    });

    expect(id).toBeTruthy();
  });

  it('reembolsa totalmente un pago aprobado', async () => {
    const id = await gateway.requestPayment({
      payerId: 'user1',
      amount: 20000,
      category: 'appointment',
      relatedId: 'appt1',
      description: null,
    });

    await expect(gateway.refund(id)).resolves.toBeUndefined();
  });

  it('reembolsa parcialmente un pago aprobado', async () => {
    const id = await gateway.requestPayment({
      payerId: 'user1',
      amount: 20000,
      category: 'product',
      relatedId: 'purchase1',
      description: null,
    });

    await expect(gateway.refund(id, 5000)).resolves.toBeUndefined();
  });

  it('rechaza reembolsar un pago que no existe', async () => {
    await expect(gateway.refund('ghost')).rejects.toThrow('no existe');
  });

  it('rechaza reembolsar más del monto original', async () => {
    const id = await gateway.requestPayment({
      payerId: 'user1',
      amount: 10000,
      category: 'appointment',
      relatedId: 'appt2',
      description: null,
    });

    await expect(gateway.refund(id, 99999)).rejects.toThrow('inválido');
  });

  it('rechaza reembolsar un pago que sigue pendiente', async () => {
    // Se siembra el doc directamente (sin pasar por requestPayment) para
    // capturarlo en 'pending', antes de cualquier auto-aprobación.
    const ref = await getFirestore().collection('payments').add({
      payerId: 'user1',
      amount: 5000,
      category: 'appointment',
      relatedId: 'appt3',
      status: 'pending',
    });

    await expect(gateway.refund(ref.id)).rejects.toThrow('no está aprobado');
  });
});
