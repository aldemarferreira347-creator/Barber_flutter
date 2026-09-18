import { Timestamp } from 'firebase-admin/firestore';

/** Convierte un valor leído de Firestore (Timestamp) o ya en memoria (Date) a Date. */
export function toJsDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  throw new Error('Fecha inválida.');
}

/** "HH:mm" en UTC — el resto de la app tampoco hace conversión de huso horario. */
export function formatTimeUTC(date: Date): string {
  const hours = date.getUTCHours().toString().padStart(2, '0');
  const minutes = date.getUTCMinutes().toString().padStart(2, '0');
  return `${hours}:${minutes}`;
}

/** Fin del día (23:59:59.999 UTC) de la fecha dada — usado para acotar "el resto de hoy". */
export function endOfDayUTC(date: Date): Date {
  const end = new Date(date);
  end.setUTCHours(23, 59, 59, 999);
  return end;
}
