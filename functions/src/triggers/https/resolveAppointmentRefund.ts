import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppointmentService } from '../../appointments/appointmentService';

export function createResolveAppointmentRefundHandler(service: AppointmentService = new AppointmentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const requestId = request.data?.requestId;
    const approve = request.data?.approve;

    if (typeof requestId !== 'string' || requestId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'requestId es obligatorio.');
    }
    if (typeof approve !== 'boolean') {
      throw new HttpsError('invalid-argument', 'approve debe ser true o false.');
    }

    // La autorización real (solo el dueño de ESA barbería, o el admin) se
    // resuelve dentro del servicio, una vez que sabe a qué barbería
    // pertenece la solicitud.
    await service.resolveRefundRequest(requestId, request.auth.uid, approve);
    return { ok: true };
  });
}

export const resolveAppointmentRefund = createResolveAppointmentRefundHandler();
