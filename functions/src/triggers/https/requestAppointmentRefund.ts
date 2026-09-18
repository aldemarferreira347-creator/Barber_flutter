import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppointmentService } from '../../appointments/appointmentService';

const MAX_REASON_LENGTH = 500;
const MAX_ITEM_INDEXES = 50;

interface RequestAppointmentRefundRequest {
  appointmentId: unknown;
  reason: unknown;
  purchaseId?: unknown;
  purchaseItemIndexes?: unknown;
}

function validate(data: RequestAppointmentRefundRequest) {
  const appointmentId = data.appointmentId;
  const reason = data.reason;
  const purchaseId = data.purchaseId ?? null;
  const purchaseItemIndexes = data.purchaseItemIndexes ?? null;

  if (typeof appointmentId !== 'string' || appointmentId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'appointmentId es obligatorio.');
  }
  if (typeof reason !== 'string' || reason.trim().length === 0 || reason.length > MAX_REASON_LENGTH) {
    throw new HttpsError('invalid-argument', `reason es obligatorio (máx. ${MAX_REASON_LENGTH} caracteres).`);
  }
  if (purchaseId !== null && (typeof purchaseId !== 'string' || purchaseId.trim().length === 0)) {
    throw new HttpsError('invalid-argument', 'purchaseId inválido.');
  }
  if (purchaseItemIndexes !== null) {
    if (!Array.isArray(purchaseItemIndexes) || purchaseItemIndexes.length > MAX_ITEM_INDEXES) {
      throw new HttpsError('invalid-argument', 'purchaseItemIndexes debe ser un arreglo de números.');
    }
    if (purchaseItemIndexes.some((index) => typeof index !== 'number')) {
      throw new HttpsError('invalid-argument', 'purchaseItemIndexes debe ser un arreglo de números.');
    }
  }

  return {
    appointmentId,
    reason,
    purchaseId: purchaseId as string | null,
    purchaseItemIndexes: purchaseItemIndexes as number[] | null,
  };
}

export function createRequestAppointmentRefundHandler(service: AppointmentService = new AppointmentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    const id = await service.requestRefund({ ...input, clientId: request.auth.uid });
    return { id };
  });
}

export const requestAppointmentRefund = createRequestAppointmentRefundHandler();
