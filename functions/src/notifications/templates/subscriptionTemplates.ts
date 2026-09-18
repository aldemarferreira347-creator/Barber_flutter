import { NotificationTone } from '../types';

interface SubscriptionStatusData {
  barbershopName: string;
}

type StatusRenderer = (data: SubscriptionStatusData) => { title: string; body: string };

/** Mensualidad vencida, en período de gracia (spec 12.5): al dueño. */
const SUBSCRIPTION_OVERDUE: Record<NotificationTone, StatusRenderer> = {
  formal: (d) => ({
    title: 'Mensualidad vencida',
    body: `La mensualidad de "${d.barbershopName}" venció. Cuenta con unos días de gracia antes del bloqueo — por favor regularice el pago desde la app.`,
  }),
  normal: (d) => ({
    title: 'Mensualidad vencida',
    body: `La mensualidad de "${d.barbershopName}" venció. Tienes unos días de gracia antes del bloqueo — paga desde la app para evitarlo.`,
  }),
  friendly: (d) => ({
    title: '¡Se venció tu mensualidad!',
    body: `La mensualidad de "${d.barbershopName}" ya venció. Tienes unos días de gracia, así que paga pronto para que todo siga funcionando.`,
  }),
  informal: (d) => ({
    title: 'Ojo, mensualidad vencida',
    body: `"${d.barbershopName}" tiene la mensualidad vencida. Quedan pocos días de gracia antes del bloqueo, así que paga ya.`,
  }),
};

/** Mensualidad bloqueada (fin del período de gracia o cancelación directa, spec 12.5/12.6): al dueño. */
const SUBSCRIPTION_BLOCKED: Record<NotificationTone, StatusRenderer> = {
  formal: (d) => ({
    title: 'Barbería bloqueada',
    body: `"${d.barbershopName}" fue bloqueada por falta de pago. La barbería y sus barberos no pueden operar hasta que regularice la mensualidad.`,
  }),
  normal: (d) => ({
    title: 'Barbería bloqueada',
    body: `"${d.barbershopName}" quedó bloqueada por falta de pago. No podrá operar hasta que pagues la mensualidad.`,
  }),
  friendly: (d) => ({
    title: 'Tu barbería quedó en pausa',
    body: `"${d.barbershopName}" quedó bloqueada por la mensualidad pendiente. Paga cuando puedas para volver a operar.`,
  }),
  informal: (d) => ({
    title: 'Barbería bloqueada',
    body: `"${d.barbershopName}" quedó bloqueada por la mensualidad. Paga para desbloquearla.`,
  }),
};

export function renderSubscriptionStatusNotice(
  kind: 'overdue' | 'blocked',
  tone: NotificationTone,
  data: SubscriptionStatusData,
): { title: string; body: string } {
  const table = kind === 'overdue' ? SUBSCRIPTION_OVERDUE : SUBSCRIPTION_BLOCKED;
  return table[tone](data);
}

interface AppointmentCancelledData {
  barbershopName: string;
  serviceName: string;
}

type CancelledRenderer = (data: AppointmentCancelledData) => { title: string; body: string };

/** La cita del cliente se canceló automáticamente porque la barbería quedó bloqueada (spec 12.6): al cliente. */
const APPOINTMENT_CANCELLED_BY_BLOCK: Record<NotificationTone, CancelledRenderer> = {
  formal: (d) => ({
    title: 'Su cita fue cancelada y reembolsada',
    body: `Su cita de ${d.serviceName} en ${d.barbershopName} fue cancelada porque la barbería quedó temporalmente fuera de servicio. Su pago fue reembolsado en su totalidad.`,
  }),
  normal: (d) => ({
    title: 'Tu cita fue cancelada y reembolsada',
    body: `Tu cita de ${d.serviceName} en ${d.barbershopName} se canceló porque la barbería quedó fuera de servicio. Ya te reembolsamos el pago.`,
  }),
  friendly: (d) => ({
    title: 'Tu cita se canceló, ¡pero tu plata está a salvo!',
    body: `${d.barbershopName} quedó fuera de servicio, así que tu ${d.serviceName} se canceló. Ya te devolvimos el pago completo.`,
  }),
  informal: (d) => ({
    title: 'Cita cancelada y reembolsada',
    body: `${d.barbershopName} quedó fuera de servicio, se canceló tu ${d.serviceName}. Ya te devolvimos la plata.`,
  }),
};

export function renderAppointmentCancelledByBlockNotice(
  tone: NotificationTone,
  data: AppointmentCancelledData,
): { title: string; body: string } {
  return APPOINTMENT_CANCELLED_BY_BLOCK[tone](data);
}
