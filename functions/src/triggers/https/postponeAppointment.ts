import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppointmentService } from '../../appointments/appointmentService';

export function createPostponeAppointmentHandler(service: AppointmentService = new AppointmentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const appointmentId = request.data?.appointmentId;
    const newDateRaw = request.data?.newDate;

    if (typeof appointmentId !== 'string' || appointmentId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'appointmentId es obligatorio.');
    }
    const newDate = typeof newDateRaw === 'string' ? new Date(newDateRaw) : null;
    if (!newDate || Number.isNaN(newDate.getTime())) {
      throw new HttpsError('invalid-argument', 'newDate debe ser una fecha ISO válida.');
    }
    if (newDate.getTime() <= Date.now()) {
      throw new HttpsError('invalid-argument', 'La nueva fecha debe ser en el futuro.');
    }

    await service.postponePaidAppointment(appointmentId, request.auth.uid, newDate);
    return { ok: true };
  });
}

export const postponeAppointment = createPostponeAppointmentHandler();
