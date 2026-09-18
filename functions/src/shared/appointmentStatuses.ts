/**
 * Estados de una cita todavía "viva" (no cancelada ni completada) — usados
 * donde hace falta actuar sobre reservas próximas de una barbería (cierre
 * por evento externo, bloqueo por mensualidad vencida).
 */
export const UPCOMING_APPOINTMENT_STATUSES = new Set(['pending', 'accepted', 'postponed']);
