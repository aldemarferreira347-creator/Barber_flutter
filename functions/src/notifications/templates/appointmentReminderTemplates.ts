import { NotificationTone } from '../types';

export interface ReminderTemplateData {
  serviceName: string;
  barbershopName: string;
  time: string;
}

type ReminderRenderer = (data: ReminderTemplateData) => { title: string; body: string };

const ONE_HOUR: Record<NotificationTone, ReminderRenderer> = {
  formal: (d) => ({
    title: 'Recordatorio de su cita',
    body: `Le recordamos que tiene una cita de ${d.serviceName} en ${d.barbershopName} a las ${d.time}, dentro de una hora.`,
  }),
  normal: (d) => ({
    title: 'Recordatorio de cita',
    body: `Tu cita de ${d.serviceName} en ${d.barbershopName} es a las ${d.time}, en una hora.`,
  }),
  friendly: (d) => ({
    title: '¡Ya casi es tu turno!',
    body: `En una hora te esperan en ${d.barbershopName} para tu ${d.serviceName} (${d.time}). ¡No faltes!`,
  }),
  informal: (d) => ({
    title: 'Se viene tu cita',
    body: `En 1 hora tienes ${d.serviceName} en ${d.barbershopName} (${d.time}). No lo olvides.`,
  }),
};

const FIFTEEN_MIN: Record<NotificationTone, ReminderRenderer> = {
  formal: (d) => ({
    title: 'Su cita comienza pronto',
    body: `Su cita de ${d.serviceName} en ${d.barbershopName} comienza en 15 minutos (${d.time}).`,
  }),
  normal: (d) => ({
    title: 'Tu cita es en 15 minutos',
    body: `Tu cita de ${d.serviceName} en ${d.barbershopName} es a las ${d.time}, en 15 minutos.`,
  }),
  friendly: (d) => ({
    title: '¡Ya casi! 15 minutos',
    body: `Tu turno de ${d.serviceName} en ${d.barbershopName} es a las ${d.time}, en 15 minutos. ¡Nos vemos pronto!`,
  }),
  informal: (d) => ({
    title: 'Ya casi es la hora',
    body: `15 minutos para tu cita de ${d.serviceName} en ${d.barbershopName} (${d.time}). Alista los pasos.`,
  }),
};

export function renderAppointmentReminder(
  kind: '1h' | '15m',
  tone: NotificationTone,
  data: ReminderTemplateData,
): { title: string; body: string } {
  const table = kind === '1h' ? ONE_HOUR : FIFTEEN_MIN;
  return table[tone](data);
}
