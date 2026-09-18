import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { RequestOwnershipInput } from './types';

/**
 * Rol de Dueño (spec 12.1): el cliente ya creó la barbería (pendiente de
 * aprobación) mediante un create() directo; este paso solo promueve su
 * rol a 'owner' — algo que el cliente no puede hacerse a sí mismo vía
 * Firestore (las reglas congelan el propio rol), por eso pasa por Admin
 * SDK. Es idempotente: si ya es Dueño (por otra barbería, spec 12.2) o
 * Admin, no toca el rol. Tener el rol sin barbería aprobada no da ningún
 * permiso adicional — eso lo decide el cliente mirando approvalStatus.
 */
export class OwnershipService {
  async requestOwnership(input: RequestOwnershipInput): Promise<void> {
    const firestore = getFirestore();
    const shopRef = firestore.doc(`barbershops/${input.barbershopId}`);
    const shopSnap = await shopRef.get();
    if (!shopSnap.exists) throw new HttpsError('not-found', 'La barbería no existe.');
    const shop = shopSnap.data()!;

    if (shop.ownerId !== input.requestedBy) {
      throw new HttpsError('permission-denied', 'Solo quien registró esta barbería puede solicitar el rol de dueño sobre ella.');
    }

    const userRef = firestore.doc(`users/${input.requestedBy}`);
    const userSnap = await userRef.get();
    if (!userSnap.exists) throw new HttpsError('not-found', 'No se encontró tu perfil.');
    const user = userSnap.data()!;

    if (user.role === 'client') {
      await userRef.update({ role: 'owner' });
    }
  }
}
