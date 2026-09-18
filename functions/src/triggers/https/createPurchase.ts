import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { PurchaseService } from '../../products/purchaseService';

const MAX_ITEMS = 20;

interface CreatePurchaseRequest {
  barbershopId: unknown;
  items: unknown;
  appointmentId?: unknown;
}

function validate(data: CreatePurchaseRequest) {
  const barbershopId = data.barbershopId;
  const items = data.items;
  const appointmentId = data.appointmentId ?? null;

  if (typeof barbershopId !== 'string' || barbershopId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'barbershopId es obligatorio.');
  }
  if (!Array.isArray(items) || items.length === 0 || items.length > MAX_ITEMS) {
    throw new HttpsError('invalid-argument', `items debe tener entre 1 y ${MAX_ITEMS} elementos.`);
  }

  const parsedItems = items.map((item: { productId?: unknown; quantity?: unknown }) => {
    if (typeof item?.productId !== 'string' || item.productId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Cada ítem necesita un productId.');
    }
    if (typeof item?.quantity !== 'number' || !Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new HttpsError('invalid-argument', 'Cada ítem necesita una cantidad entera positiva.');
    }
    return { productId: item.productId, quantity: item.quantity };
  });

  if (appointmentId !== null && (typeof appointmentId !== 'string' || appointmentId.trim().length === 0)) {
    throw new HttpsError('invalid-argument', 'appointmentId inválido.');
  }

  return { barbershopId, items: parsedItems, appointmentId: appointmentId as string | null };
}

export function createCreatePurchaseHandler(service: PurchaseService = new PurchaseService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    const id = await service.createPurchase({ ...input, buyerId: request.auth.uid });
    return { id };
  });
}

export const createPurchase = createCreatePurchaseHandler();
