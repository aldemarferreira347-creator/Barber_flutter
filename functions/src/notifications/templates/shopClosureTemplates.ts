import { NotificationTone } from '../types';

interface ShopClosureData {
  barbershopName: string;
  serviceName: string;
}

type Renderer = (data: ShopClosureData) => { title: string; body: string };

/** La barbería cierra por un evento externo y la cita pagada del cliente queda aplazada (spec 3.4). */
const SHOP_CLOSURE: Record<NotificationTone, Renderer> = {
  formal: (d) => ({
    title: `${d.barbershopName} debió cerrar temporalmente`,
    body: `Lamentamos informarle que, por un evento externo a la barbería, su cita de ${d.serviceName} debió aplazarse. Su pago se conserva; por favor elija una nueva fecha desde la app.`,
  }),
  normal: (d) => ({
    title: `${d.barbershopName} cerró temporalmente`,
    body: `Por un evento externo, ${d.barbershopName} tuvo que cerrar y tu cita de ${d.serviceName} quedó aplazada. Tu pago sigue en pie: elige una nueva fecha cuando quieras.`,
  }),
  friendly: (d) => ({
    title: 'Cambio de planes, ¡pero tranquilo!',
    body: `${d.barbershopName} tuvo que cerrar por algo externo y tu ${d.serviceName} quedó aplazado. Tu pago está seguro, solo elige otra fecha y ahí te esperamos.`,
  }),
  informal: (d) => ({
    title: 'Toca reprogramar',
    body: `${d.barbershopName} cerró por algo externo, así que tu ${d.serviceName} quedó aplazado. Tu plata está segura, elige otra fecha cuando puedas.`,
  }),
};

export function renderShopClosureNotice(tone: NotificationTone, data: ShopClosureData): { title: string; body: string } {
  return SHOP_CLOSURE[tone](data);
}
