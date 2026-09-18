import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { SimulatedNequiGateway } from '../../payments/nequiGateway';
import { PaymentGatewayAdapter } from '../../payments/types';

interface RefundPaymentRequest {
  paymentId: unknown;
  amount?: unknown;
}

function validate(data: RefundPaymentRequest) {
  const paymentId = data.paymentId;
  const amount = data.amount;

  if (typeof paymentId !== 'string' || paymentId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'paymentId es obligatorio.');
  }
  if (amount !== undefined && (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0)) {
    throw new HttpsError('invalid-argument', 'amount debe ser un número positivo si se especifica.');
  }

  return { paymentId, amount: amount as number | undefined };
}

/**
 * Reservado al admin por ahora: el flujo real de reembolso con
 * justificación y aprobación del dueño de la barbería (spec 6.5) llega en
 * una fase posterior y reutilizará esta misma función, ampliando quién
 * puede autorizarlo — no su lógica de reembolso en sí.
 */
export function createRefundPaymentHandler(gateway: PaymentGatewayAdapter = new SimulatedNequiGateway()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const callerDoc = await getFirestore().doc(`users/${request.auth.uid}`).get();
    if (callerDoc.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo un administrador puede procesar este reembolso.');
    }

    const input = validate(request.data ?? {});
    await gateway.refund(input.paymentId, input.amount);
    return { ok: true };
  });
}

export const refundPayment = createRefundPaymentHandler();
