import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { SimulatedNequiGateway } from '../payments/nequiGateway';
import { PaymentGatewayAdapter } from '../payments/types';
import { assertStaffOfShop } from '../shared/shopAuthorization';
import { generateClaimCode } from './claimCode';
import { CreatePurchaseInput, PurchaseItemRecord } from './types';

const CLAIM_WINDOW_MS = 24 * 60 * 60 * 1000;

/**
 * Lógica de negocio de compras de productos (spec 10.1–10.5), separada del
 * trigger HTTPS para poder probarla sin pasar por onCall. [gateway] solo se
 * sobreescribe en tests.
 */
export class PurchaseService {
  constructor(private readonly gateway: PaymentGatewayAdapter = new SimulatedNequiGateway()) {}

  async createPurchase(input: CreatePurchaseInput): Promise<string> {
    if (input.items.length === 0) {
      throw new HttpsError('invalid-argument', 'La compra debe incluir al menos un producto.');
    }

    const firestore = getFirestore();
    const productsRef = firestore.collection('barbershops').doc(input.barbershopId).collection('products');

    // Los precios SIEMPRE se recalculan desde el catálogo real — nunca se
    // confía en un precio enviado por el cliente.
    const items: PurchaseItemRecord[] = [];
    for (const requested of input.items) {
      if (!Number.isInteger(requested.quantity) || requested.quantity <= 0) {
        throw new HttpsError('invalid-argument', `Cantidad inválida para ${requested.productId}.`);
      }
      const productSnap = await productsRef.doc(requested.productId).get();
      if (!productSnap.exists || productSnap.data()?.active !== true) {
        throw new HttpsError('failed-precondition', `El producto ${requested.productId} ya no está disponible.`);
      }
      const product = productSnap.data()!;
      items.push({
        productId: requested.productId,
        productName: product.name as string,
        unitPrice: product.price as number,
        quantity: requested.quantity,
        refunded: false,
      });
    }

    const totalAmount = items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);

    const draftRef = await firestore.collection('purchases').add({
      barbershopId: input.barbershopId,
      buyerId: input.buyerId,
      appointmentId: input.appointmentId,
      items,
      totalAmount,
      paymentId: null,
      claimCode: null,
      status: 'pending_payment',
      createdAt: FieldValue.serverTimestamp(),
      claimedAt: null,
      expiresAt: null,
    });

    try {
      const paymentId = await this.gateway.requestPayment({
        payerId: input.buyerId,
        amount: totalAmount,
        category: 'product',
        relatedId: draftRef.id,
        description: `Compra de productos en barbershops/${input.barbershopId}`,
      });

      await draftRef.update({
        paymentId,
        claimCode: generateClaimCode(),
        status: 'pending_claim',
        expiresAt: new Date(Date.now() + CLAIM_WINDOW_MS),
      });
    } catch (error) {
      await draftRef.update({ status: 'payment_failed' });
      throw error;
    }

    return draftRef.id;
  }

  async claimPurchase(purchaseId: string, callerUid: string): Promise<void> {
    const firestore = getFirestore();
    const ref = firestore.collection('purchases').doc(purchaseId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError('not-found', 'La compra no existe.');

    const data = snapshot.data()!;
    await assertStaffOfShop(callerUid, data.barbershopId as string);

    if (data.status !== 'pending_claim') {
      throw new HttpsError('failed-precondition', `La compra no está lista para reclamar (status: ${data.status}).`);
    }

    await ref.update({ status: 'claimed', claimedAt: FieldValue.serverTimestamp() });
  }

  async refundItems(purchaseId: string, itemIndexes: number[]): Promise<void> {
    if (itemIndexes.length === 0) {
      throw new HttpsError('invalid-argument', 'Selecciona al menos un ítem para reembolsar.');
    }

    const ref = getFirestore().collection('purchases').doc(purchaseId);
    const snapshot = await ref.get();
    if (!snapshot.exists) throw new HttpsError('not-found', 'La compra no existe.');

    const data = snapshot.data()!;
    const items: PurchaseItemRecord[] = data.items ?? [];

    for (const index of itemIndexes) {
      if (!Number.isInteger(index) || index < 0 || index >= items.length) {
        throw new HttpsError('invalid-argument', `Índice de ítem inválido: ${index}.`);
      }
      if (items[index].refunded) {
        throw new HttpsError('failed-precondition', `El ítem ${index} ya fue reembolsado.`);
      }
    }
    if (!data.paymentId) {
      throw new HttpsError('failed-precondition', 'La compra no tiene un pago asociado.');
    }

    const refundAmount = itemIndexes.reduce((sum, index) => sum + items[index].unitPrice * items[index].quantity, 0);
    await this.gateway.refund(data.paymentId as string, refundAmount);

    const updatedItems = items.map((item, index) => (itemIndexes.includes(index) ? { ...item, refunded: true } : item));
    await ref.update({ items: updatedItems });
  }

  /** Barre las compras cuyo código de reclamo ya venció sin usarse (spec 10.4). */
  async expireOverduePurchases(now: Date = new Date()): Promise<number> {
    const firestore = getFirestore();
    const snapshot = await firestore
      .collection('purchases')
      .where('status', '==', 'pending_claim')
      .where('expiresAt', '<=', now)
      .get();

    if (snapshot.empty) return 0;

    const batch = firestore.batch();
    snapshot.docs.forEach((doc) => batch.update(doc.ref, { status: 'expired' }));
    await batch.commit();

    return snapshot.size;
  }
}
