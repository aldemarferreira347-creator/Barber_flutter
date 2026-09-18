import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { SimulatedNequiGateway } from '../../payments/nequiGateway';
import { PaymentCategory, PaymentGatewayAdapter } from '../../payments/types';

const ALLOWED_CATEGORIES: readonly PaymentCategory[] = ['appointment', 'product', 'subscription'];
const MAX_DESCRIPTION_LENGTH = 300;

interface RequestPaymentRequest {
  amount: unknown;
  category: unknown;
  relatedId: unknown;
  description?: unknown;
}

function validate(data: RequestPaymentRequest) {
  const amount = data.amount;
  const category = data.category;
  const relatedId = data.relatedId;
  const description = data.description ?? null;

  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError('invalid-argument', 'amount debe ser un número positivo.');
  }
  if (typeof category !== 'string' || !ALLOWED_CATEGORIES.includes(category as PaymentCategory)) {
    throw new HttpsError('invalid-argument', 'category inválida.');
  }
  if (typeof relatedId !== 'string' || relatedId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'relatedId es obligatorio.');
  }
  if (description !== null && (typeof description !== 'string' || description.length > MAX_DESCRIPTION_LENGTH)) {
    throw new HttpsError('invalid-argument', `description debe ser texto (máx. ${MAX_DESCRIPTION_LENGTH} caracteres).`);
  }

  return { amount, category: category as PaymentCategory, relatedId, description: description as string | null };
}

/** [gateway] solo se sobreescribe en tests — en producción siempre es la pasarela real configurada. */
export function createRequestPaymentHandler(gateway: PaymentGatewayAdapter = new SimulatedNequiGateway()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    const id = await gateway.requestPayment({ ...input, payerId: request.auth.uid });
    return { id };
  });
}

export const requestPayment = createRequestPaymentHandler();
