import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

async function loadCaller(callerUid: string) {
  const snapshot = await getFirestore().doc(`users/${callerUid}`).get();
  const caller = snapshot.data();
  if (!caller) throw new HttpsError('permission-denied', 'No se encontró tu perfil.');
  return caller;
}

async function isOwnerOfShop(callerUid: string, barbershopId: string): Promise<boolean> {
  const shopSnap = await getFirestore().doc(`barbershops/${barbershopId}`).get();
  return shopSnap.data()?.ownerId === callerUid;
}

/**
 * Admin, o dueño/barbero de ESA barbería específicamente (nunca de otra) —
 * usado donde cualquier miembro del personal puede actuar (p.ej. reclamar
 * una compra, spec 10.4).
 */
export async function assertStaffOfShop(callerUid: string, barbershopId: string): Promise<void> {
  const caller = await loadCaller(callerUid);

  if (caller.role === 'admin') return;
  if (caller.role === 'barber' && caller.barbershopId === barbershopId) return;
  if (caller.role === 'owner' && (await isOwnerOfShop(callerUid, barbershopId))) return;

  throw new HttpsError('permission-denied', 'No tienes permiso sobre esa barbería.');
}

/**
 * Admin, o específicamente el DUEÑO de esa barbería (nunca un barbero) —
 * usado donde el spec reserva la acción al dueño (p.ej. aprobar
 * reembolsos, spec 6.5).
 */
export async function assertOwnerOfShop(callerUid: string, barbershopId: string): Promise<void> {
  const caller = await loadCaller(callerUid);

  if (caller.role === 'admin') return;
  if (caller.role === 'owner' && (await isOwnerOfShop(callerUid, barbershopId))) return;

  throw new HttpsError('permission-denied', 'Solo el dueño de esa barbería puede hacer esto.');
}
