import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { SimulatedNequiGateway } from '../payments/nequiGateway';
import { PaymentGatewayAdapter } from '../payments/types';
import { PurchaseService } from '../products/purchaseService';
import { assertOwnerOfShop } from '../shared/shopAuthorization';
import { slotId } from './slotId';
import { BookPaidAppointmentInput, RequestAppointmentRefundInput } from './types';

const NON_POSTPONABLE_STATUSES = new Set(['cancelled', 'completed']);

function toDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  throw new HttpsError('internal', 'Fecha de cita inválida.');
}

/**
 * Lógica de negocio de citas pagadas (spec 6.1–6.5), separada del trigger
 * HTTPS para poder probarla sin pasar por onCall. [gateway] solo se
 * sobreescribe en tests.
 */
export class AppointmentService {
  constructor(private readonly gateway: PaymentGatewayAdapter = new SimulatedNequiGateway()) {}

  /**
   * Reserva pagada: bloquea el horario con una transacción (create()
   * atómico sobre appointmentSlots/{id}) ANTES de cobrar, para que dos
   * clientes nunca puedan ganar el mismo horario (spec 6.2). Las reservas
   * SIN pago (spec 6.1) no pasan por aquí — siguen creándose directo desde
   * el cliente, sin bloquear nada.
   */
  async bookPaidAppointment(input: BookPaidAppointmentInput): Promise<string> {
    const firestore = getFirestore();

    const serviceSnap = await firestore
      .collection('barbershops')
      .doc(input.barbershopId)
      .collection('services')
      .doc(input.serviceId)
      .get();
    if (!serviceSnap.exists || serviceSnap.data()?.active !== true) {
      throw new HttpsError('failed-precondition', 'Ese servicio ya no está disponible.');
    }
    const service = serviceSnap.data()!;

    const slotRef = firestore.collection('appointmentSlots').doc(slotId(input.barberId, input.date));
    const appointmentRef = firestore.collection('appointments').doc();

    await firestore.runTransaction(async (tx) => {
      const slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        throw new HttpsError('already-exists', 'Ese horario ya no está disponible.');
      }
      tx.set(slotRef, { appointmentId: appointmentRef.id, barberId: input.barberId, createdAt: FieldValue.serverTimestamp() });
      tx.set(appointmentRef, {
        barbershopId: input.barbershopId,
        barberId: input.barberId,
        barberName: input.barberName,
        clientId: input.clientId,
        clientName: input.clientName,
        serviceId: input.serviceId,
        serviceName: service.name,
        servicePrice: service.price,
        durationMinutes: service.durationMinutes,
        date: input.date,
        status: 'pending',
        paid: true,
        paymentId: null,
        rescheduleHistory: [],
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    try {
      const paymentId = await this.gateway.requestPayment({
        payerId: input.clientId,
        amount: service.price as number,
        category: 'appointment',
        relatedId: appointmentRef.id,
        description: `Cita en barbershops/${input.barbershopId}`,
      });
      await appointmentRef.update({ paymentId });
    } catch (error) {
      // Si el pago falla, se libera el horario para que otro cliente pueda tomarlo.
      await Promise.all([appointmentRef.update({ status: 'cancelled' }), slotRef.delete()]);
      throw error;
    }

    return appointmentRef.id;
  }

  /**
   * Posponer una cita pagada (spec 6.4): conserva el pago, libera el
   * horario viejo y reclama el nuevo con la misma transacción atómica que
   * usa la reserva original, y deja constancia en rescheduleHistory.
   */
  async postponePaidAppointment(appointmentId: string, callerUid: string, newDate: Date): Promise<void> {
    const firestore = getFirestore();
    const appointmentRef = firestore.collection('appointments').doc(appointmentId);
    const appointmentSnap = await appointmentRef.get();
    if (!appointmentSnap.exists) throw new HttpsError('not-found', 'La cita no existe.');
    const appointment = appointmentSnap.data()!;

    const isClient = appointment.clientId === callerUid;
    const isAssignedBarber = appointment.barberId === callerUid;
    if (!isClient && !isAssignedBarber) {
      await assertOwnerOfShop(callerUid, appointment.barbershopId as string);
    }
    if (appointment.paid !== true) {
      throw new HttpsError('failed-precondition', 'Esta cita no está pagada.');
    }
    if (NON_POSTPONABLE_STATUSES.has(appointment.status as string)) {
      throw new HttpsError('failed-precondition', `No se puede posponer una cita ${appointment.status}.`);
    }

    const oldDate = toDate(appointment.date);
    const oldSlotRef = firestore.collection('appointmentSlots').doc(slotId(appointment.barberId as string, oldDate));
    const newSlotRef = firestore.collection('appointmentSlots').doc(slotId(appointment.barberId as string, newDate));

    await firestore.runTransaction(async (tx) => {
      const newSlotSnap = await tx.get(newSlotRef);
      if (newSlotSnap.exists) {
        throw new HttpsError('already-exists', 'Ese nuevo horario ya no está disponible.');
      }
      tx.delete(oldSlotRef);
      tx.set(newSlotRef, { appointmentId, barberId: appointment.barberId, createdAt: FieldValue.serverTimestamp() });
      tx.update(appointmentRef, {
        date: newDate,
        status: 'postponed',
        rescheduleHistory: FieldValue.arrayUnion({ from: appointment.date, to: newDate }),
      });
    });
  }

  /**
   * Crea la solicitud de cancelación con justificación (spec 6.3) — no
   * cancela nada todavía, eso queda para [resolveRefundRequest] tras la
   * aprobación del dueño.
   */
  async requestRefund(input: RequestAppointmentRefundInput): Promise<string> {
    if (input.reason.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Debes indicar una justificación.');
    }

    const firestore = getFirestore();
    const appointmentSnap = await firestore.collection('appointments').doc(input.appointmentId).get();
    if (!appointmentSnap.exists) throw new HttpsError('not-found', 'La cita no existe.');
    const appointment = appointmentSnap.data()!;

    if (appointment.clientId !== input.clientId) {
      throw new HttpsError('permission-denied', 'Solo el cliente de esta cita puede solicitar el reembolso.');
    }
    if (appointment.paid !== true) {
      throw new HttpsError('failed-precondition', 'Esta cita no está pagada — puedes cancelarla directamente.');
    }
    if (appointment.status === 'cancelled') {
      throw new HttpsError('failed-precondition', 'Esta cita ya está cancelada.');
    }

    const ref = await firestore.collection('refundRequests').add({
      appointmentId: input.appointmentId,
      barbershopId: appointment.barbershopId,
      clientId: input.clientId,
      reason: input.reason.trim(),
      purchaseId: input.purchaseId,
      purchaseItemIndexes: input.purchaseItemIndexes,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
      resolvedAt: null,
      resolvedBy: null,
    });

    return ref.id;
  }

  /** El dueño de la barbería (o el admin) aprueba o rechaza la solicitud (spec 6.5). */
  async resolveRefundRequest(requestId: string, callerUid: string, approve: boolean): Promise<void> {
    const firestore = getFirestore();
    const requestRef = firestore.collection('refundRequests').doc(requestId);
    const requestSnap = await requestRef.get();
    if (!requestSnap.exists) throw new HttpsError('not-found', 'La solicitud no existe.');
    const request = requestSnap.data()!;

    if (request.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Esta solicitud ya fue resuelta.');
    }

    await assertOwnerOfShop(callerUid, request.barbershopId as string);

    if (!approve) {
      await requestRef.update({ status: 'rejected', resolvedAt: FieldValue.serverTimestamp(), resolvedBy: callerUid });
      return;
    }

    const appointmentRef = firestore.collection('appointments').doc(request.appointmentId as string);
    const appointmentSnap = await appointmentRef.get();
    if (!appointmentSnap.exists) throw new HttpsError('not-found', 'La cita ya no existe.');
    const appointment = appointmentSnap.data()!;

    if (appointment.paymentId) {
      await this.gateway.refund(appointment.paymentId as string);
    }
    if (request.purchaseId && Array.isArray(request.purchaseItemIndexes) && request.purchaseItemIndexes.length > 0) {
      const purchaseService = new PurchaseService(this.gateway);
      await purchaseService.refundItems(request.purchaseId as string, request.purchaseItemIndexes as number[]);
    }

    const slotRef = firestore.collection('appointmentSlots').doc(slotId(appointment.barberId as string, toDate(appointment.date)));

    await Promise.all([
      appointmentRef.update({ status: 'cancelled' }),
      slotRef.delete(),
      requestRef.update({ status: 'approved', resolvedAt: FieldValue.serverTimestamp(), resolvedBy: callerUid }),
    ]);
  }
}
