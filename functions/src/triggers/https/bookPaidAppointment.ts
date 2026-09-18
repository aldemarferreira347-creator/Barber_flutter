import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { AppointmentService } from '../../appointments/appointmentService';

interface BookPaidAppointmentRequest {
  barbershopId: unknown;
  barberId: unknown;
  barberName: unknown;
  serviceId: unknown;
  clientName: unknown;
  date: unknown;
}

function validate(data: BookPaidAppointmentRequest) {
  const { barbershopId, barberId, barberName, serviceId, clientName, date } = data;

  for (const [key, value] of Object.entries({ barbershopId, barberId, barberName, serviceId, clientName })) {
    if (typeof value !== 'string' || value.trim().length === 0) {
      throw new HttpsError('invalid-argument', `${key} es obligatorio.`);
    }
  }

  const parsedDate = typeof date === 'string' ? new Date(date) : null;
  if (!parsedDate || Number.isNaN(parsedDate.getTime())) {
    throw new HttpsError('invalid-argument', 'date debe ser una fecha ISO válida.');
  }
  if (parsedDate.getTime() <= Date.now()) {
    throw new HttpsError('invalid-argument', 'La cita debe ser en el futuro.');
  }

  return {
    barbershopId: barbershopId as string,
    barberId: barberId as string,
    barberName: barberName as string,
    serviceId: serviceId as string,
    clientName: clientName as string,
    date: parsedDate,
  };
}

export function createBookPaidAppointmentHandler(service: AppointmentService = new AppointmentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    const id = await service.bookPaidAppointment({ ...input, clientId: request.auth.uid });
    return { id };
  });
}

export const bookPaidAppointment = createBookPaidAppointmentHandler();
