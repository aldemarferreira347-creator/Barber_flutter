import { NotificationTone } from '../types';

interface RescheduleInviteData {
  serviceName: string;
}

interface BarberBackData {
  serviceName: string;
  time: string;
}

type RescheduleRenderer = (data: RescheduleInviteData) => { title: string; body: string };
type BackRenderer = (data: BarberBackData) => { title: string; body: string };

/** El barbero no volvió dentro de su propio estimado — invita a reprogramar (spec 3.3). */
const RESCHEDULE_INVITE: Record<NotificationTone, RescheduleRenderer> = {
  formal: (d) => ({
    title: 'Su barbero no ha regresado a tiempo',
    body: `Lamentamos informarle que su cita de ${d.serviceName} debe reprogramarse porque el barbero no ha regresado a la barbería. Por favor elija una nueva fecha desde la app.`,
  }),
  normal: (d) => ({
    title: 'Tu cita debe reprogramarse',
    body: `El barbero todavía no ha vuelto a la barbería, así que tu cita de ${d.serviceName} quedó aplazada. Elige una nueva fecha cuando quieras.`,
  }),
  friendly: (d) => ({
    title: 'Necesitamos moverte de horario',
    body: `Tu barbero se demoró más de lo esperado y tu ${d.serviceName} quedó aplazado. ¡Elige otra fecha y ahí te esperamos!`,
  }),
  informal: (d) => ({
    title: 'Toca cambiar la hora',
    body: `El barbero no ha vuelto todavía, así que tu ${d.serviceName} quedó aplazado. Reprograma cuando puedas.`,
  }),
};

/** El barbero volvió dentro de su propio estimado y hay una cita en la próxima hora (spec 3.3). */
const BARBER_BACK: Record<NotificationTone, BackRenderer> = {
  formal: (d) => ({
    title: 'Su cita sigue en pie',
    body: `Le confirmamos que su barbero ya está de vuelta. Su cita de ${d.serviceName} a las ${d.time} continúa con normalidad.`,
  }),
  normal: (d) => ({
    title: 'Tu cita sigue en pie',
    body: `Tu barbero ya volvió. Tu cita de ${d.serviceName} a las ${d.time} sigue con normalidad.`,
  }),
  friendly: (d) => ({
    title: '¡Todo en orden!',
    body: `Tu barbero ya está de vuelta, así que tu ${d.serviceName} de las ${d.time} sigue en pie. ¡Nos vemos pronto!`,
  }),
  informal: (d) => ({
    title: 'Todo bien',
    body: `Ya volvió el barbero, tu ${d.serviceName} de las ${d.time} sigue de una.`,
  }),
};

export function renderRescheduleInvite(tone: NotificationTone, data: RescheduleInviteData): { title: string; body: string } {
  return RESCHEDULE_INVITE[tone](data);
}

export function renderBarberBack(tone: NotificationTone, data: BarberBackData): { title: string; body: string } {
  return BARBER_BACK[tone](data);
}
