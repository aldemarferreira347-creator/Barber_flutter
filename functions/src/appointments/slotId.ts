/**
 * Id determinístico de appointmentSlots/{id}: mismo barbero + mismo minuto
 * de inicio => mismo id. Reservarlo con un create() atómico (dentro de una
 * transacción) es lo que garantiza que solo un cliente gane ese horario
 * cuando dos lo intentan al mismo tiempo (spec 6.2).
 */
export function slotId(barberId: string, date: Date): string {
  const minuteIso = date.toISOString().slice(0, 16); // yyyy-MM-ddTHH:mm
  return `${barberId}_${minuteIso}`;
}
