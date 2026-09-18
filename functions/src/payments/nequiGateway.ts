import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import { PaymentGatewayAdapter, RequestPaymentInput } from './types';

const DEFAULT_SIMULATED_APPROVAL_DELAY_MS = 1500;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Adaptador Nequi. Hoy corre en modo simulado: no hay credenciales de
 * comercio reales todavía, así que aprueba el pago tras un breve delay en
 * vez de esperar la confirmación real del usuario desde su app Nequi
 * (que llegaría por webhook). El día que haya credenciales, esta es la
 * ÚNICA pieza que cambia — requestPayment.ts/refundPayment.ts y el resto
 * del backend ya hablan en términos de PaymentGatewayAdapter, nunca de
 * los detalles de Nequi.
 */
export class SimulatedNequiGateway implements PaymentGatewayAdapter {
  private readonly delayMs: number;

  constructor(delayMs: number = DEFAULT_SIMULATED_APPROVAL_DELAY_MS) {
    this.delayMs = delayMs;
  }

  async requestPayment(input: RequestPaymentInput): Promise<string> {
    const ref = await getFirestore()
      .collection('payments')
      .add({
        payerId: input.payerId,
        amount: input.amount,
        category: input.category,
        relatedId: input.relatedId,
        description: input.description,
        status: 'pending',
        createdAt: FieldValue.serverTimestamp(),
        resolvedAt: null,
        refundedAmount: null,
      });

    await delay(this.delayMs);
    await ref.update({ status: 'approved', resolvedAt: FieldValue.serverTimestamp() });

    return ref.id;
  }

  async refund(paymentId: string, amount?: number): Promise<void> {
    const ref = getFirestore().collection('payments').doc(paymentId);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new Error(`payments/${paymentId} no existe`);
    }

    const data = snapshot.data()!;
    if (data.status !== 'approved') {
      throw new Error(`payments/${paymentId} no está aprobado (status: ${data.status}), no se puede reembolsar`);
    }

    const refundAmount = amount ?? data.amount;
    if (typeof refundAmount !== 'number' || refundAmount <= 0 || refundAmount > data.amount) {
      throw new Error(`Monto de reembolso inválido para payments/${paymentId}`);
    }

    await ref.update({ status: 'refunded', refundedAmount: refundAmount, resolvedAt: FieldValue.serverTimestamp() });
  }
}
