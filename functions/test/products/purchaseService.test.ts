import { PurchaseService } from '../../src/products/purchaseService';
import { PaymentGatewayAdapter } from '../../src/payments/types';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
}));

function fakeGateway(overrides: Partial<PaymentGatewayAdapter> = {}): jest.Mocked<PaymentGatewayAdapter> {
  return {
    requestPayment: jest.fn().mockResolvedValue('payment1'),
    refund: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  } as jest.Mocked<PaymentGatewayAdapter>;
}

function seedProduct(shopId: string, productId: string, data: Record<string, unknown>) {
  fakeFirestore.seed(`barbershops/${shopId}/products/${productId}`, data);
}

beforeEach(() => fakeFirestore.reset());

describe('PurchaseService.createPurchase', () => {
  it('recalcula el total desde el catálogo real y genera un código de reclamo tras el pago', async () => {
    seedProduct('shop1', 'p1', { name: 'Cera', price: 15000, active: true });
    seedProduct('shop1', 'p2', { name: 'Gel', price: 10000, active: true });

    const gateway = fakeGateway();
    const service = new PurchaseService(gateway);

    const id = await service.createPurchase({
      buyerId: 'buyer1',
      barbershopId: 'shop1',
      items: [
        { productId: 'p1', quantity: 2 },
        { productId: 'p2', quantity: 1 },
      ],
      appointmentId: null,
    });

    expect(gateway.requestPayment).toHaveBeenCalledWith(
      expect.objectContaining({ payerId: 'buyer1', amount: 40000, category: 'product', relatedId: id }),
    );

    const snapshot = await fakeFirestore.doc(`purchases/${id}`).get();
    const data = snapshot.data()!;
    expect(data.status).toBe('pending_claim');
    expect(data.paymentId).toBe('payment1');
    expect(typeof data.claimCode).toBe('string');
    expect((data.claimCode as string).length).toBe(8);
    expect(data.totalAmount).toBe(40000);
  });

  it('rechaza un producto inactivo o inexistente', async () => {
    seedProduct('shop1', 'p1', { name: 'Cera', price: 15000, active: false });
    const service = new PurchaseService(fakeGateway());

    await expect(
      service.createPurchase({ buyerId: 'buyer1', barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 1 }], appointmentId: null }),
    ).rejects.toThrow('ya no está disponible');
  });

  it('rechaza una cantidad no entera o no positiva', async () => {
    seedProduct('shop1', 'p1', { name: 'Cera', price: 15000, active: true });
    const service = new PurchaseService(fakeGateway());

    await expect(
      service.createPurchase({ buyerId: 'buyer1', barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 0 }], appointmentId: null }),
    ).rejects.toThrow('Cantidad inválida');
  });

  it('si el pago falla, marca la compra payment_failed en vez de dejarla pending_payment', async () => {
    seedProduct('shop1', 'p1', { name: 'Cera', price: 15000, active: true });
    const gateway = fakeGateway({ requestPayment: jest.fn().mockRejectedValue(new Error('rechazado por Nequi')) });
    const service = new PurchaseService(gateway);

    await expect(
      service.createPurchase({ buyerId: 'buyer1', barbershopId: 'shop1', items: [{ productId: 'p1', quantity: 1 }], appointmentId: null }),
    ).rejects.toThrow('rechazado por Nequi');

    const all = await fakeFirestore.collection('purchases').where('buyerId', '==', 'buyer1').get();
    expect(all.docs).toHaveLength(1);
    expect(all.docs[0].data().status).toBe('payment_failed');
  });
});

describe('PurchaseService.claimPurchase', () => {
  async function seedPurchase(id: string, data: Record<string, unknown>) {
    fakeFirestore.seed(`purchases/${id}`, { status: 'pending_claim', barbershopId: 'shop1', ...data });
  }

  it('el barbero de esa barbería puede reclamarla', async () => {
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
    await seedPurchase('purchase1', {});
    const service = new PurchaseService(fakeGateway());

    await service.claimPurchase('purchase1', 'barber1');

    const snapshot = await fakeFirestore.doc('purchases/purchase1').get();
    expect(snapshot.data()!.status).toBe('claimed');
  });

  it('un barbero de OTRA barbería no puede reclamarla', async () => {
    fakeFirestore.seed('users/barber2', { role: 'barber', barbershopId: 'other-shop' });
    await seedPurchase('purchase2', {});
    const service = new PurchaseService(fakeGateway());

    await expect(service.claimPurchase('purchase2', 'barber2')).rejects.toThrow('No tienes permiso');
  });

  it('el dueño de la barbería puede reclamarla', async () => {
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    await seedPurchase('purchase3', {});
    const service = new PurchaseService(fakeGateway());

    await service.claimPurchase('purchase3', 'owner1');

    const snapshot = await fakeFirestore.doc('purchases/purchase3').get();
    expect(snapshot.data()!.status).toBe('claimed');
  });

  it('el admin puede reclamarla', async () => {
    fakeFirestore.seed('users/admin1', { role: 'admin' });
    await seedPurchase('purchase4', {});
    const service = new PurchaseService(fakeGateway());

    await service.claimPurchase('purchase4', 'admin1');

    const snapshot = await fakeFirestore.doc('purchases/purchase4').get();
    expect(snapshot.data()!.status).toBe('claimed');
  });

  it('un cliente sin relación con la barbería no puede reclamarla', async () => {
    fakeFirestore.seed('users/client1', { role: 'client' });
    await seedPurchase('purchase5', {});
    const service = new PurchaseService(fakeGateway());

    await expect(service.claimPurchase('purchase5', 'client1')).rejects.toThrow('No tienes permiso');
  });

  it('rechaza reclamar una compra que ya fue reclamada, expiró, o sigue pendiente de pago', async () => {
    fakeFirestore.seed('users/barber3', { role: 'barber', barbershopId: 'shop1' });
    await seedPurchase('purchase6', { status: 'claimed' });
    const service = new PurchaseService(fakeGateway());

    await expect(service.claimPurchase('purchase6', 'barber3')).rejects.toThrow('no está lista para reclamar');
  });

  it('rechaza una compra inexistente', async () => {
    const service = new PurchaseService(fakeGateway());
    await expect(service.claimPurchase('ghost', 'anyone')).rejects.toThrow('no existe');
  });
});

describe('PurchaseService.refundItems', () => {
  it('reembolsa solo los ítems seleccionados y marca refunded en cada uno', async () => {
    fakeFirestore.seed('purchases/purchase10', {
      paymentId: 'payment10',
      items: [
        { productId: 'p1', productName: 'Cera', unitPrice: 15000, quantity: 1, refunded: false },
        { productId: 'p2', productName: 'Gel', unitPrice: 10000, quantity: 2, refunded: false },
      ],
    });
    const gateway = fakeGateway();
    const service = new PurchaseService(gateway);

    await service.refundItems('purchase10', [1]);

    expect(gateway.refund).toHaveBeenCalledWith('payment10', 20000);
    const snapshot = await fakeFirestore.doc('purchases/purchase10').get();
    const items = snapshot.data()!.items as Array<{ refunded: boolean }>;
    expect(items[0].refunded).toBe(false);
    expect(items[1].refunded).toBe(true);
  });

  it('rechaza reembolsar un ítem ya reembolsado', async () => {
    fakeFirestore.seed('purchases/purchase11', {
      paymentId: 'payment11',
      items: [{ productId: 'p1', productName: 'Cera', unitPrice: 15000, quantity: 1, refunded: true }],
    });
    const service = new PurchaseService(fakeGateway());

    await expect(service.refundItems('purchase11', [0])).rejects.toThrow('ya fue reembolsado');
  });

  it('rechaza un índice fuera de rango', async () => {
    fakeFirestore.seed('purchases/purchase12', {
      paymentId: 'payment12',
      items: [{ productId: 'p1', productName: 'Cera', unitPrice: 15000, quantity: 1, refunded: false }],
    });
    const service = new PurchaseService(fakeGateway());

    await expect(service.refundItems('purchase12', [5])).rejects.toThrow('inválido');
  });

  it('exige al menos un índice', async () => {
    fakeFirestore.seed('purchases/purchase13', { paymentId: 'payment13', items: [] });
    const service = new PurchaseService(fakeGateway());

    await expect(service.refundItems('purchase13', [])).rejects.toThrow('al menos un ítem');
  });
});

describe('PurchaseService.expireOverduePurchases', () => {
  it('marca expired solo las compras pending_claim ya vencidas', async () => {
    const now = new Date('2026-01-02T00:00:00Z');
    fakeFirestore.seed('purchases/expired1', { status: 'pending_claim', expiresAt: new Date('2026-01-01T00:00:00Z') });
    fakeFirestore.seed('purchases/notYet1', { status: 'pending_claim', expiresAt: new Date('2026-01-03T00:00:00Z') });
    fakeFirestore.seed('purchases/claimedAlready1', { status: 'claimed', expiresAt: new Date('2026-01-01T00:00:00Z') });
    const service = new PurchaseService(fakeGateway());

    const count = await service.expireOverduePurchases(now);

    expect(count).toBe(1);
    expect((await fakeFirestore.doc('purchases/expired1').get()).data()!.status).toBe('expired');
    expect((await fakeFirestore.doc('purchases/notYet1').get()).data()!.status).toBe('pending_claim');
    expect((await fakeFirestore.doc('purchases/claimedAlready1').get()).data()!.status).toBe('claimed');
  });
});
