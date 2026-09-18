import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { containsOffensiveContent } from '../shared/contentModerationFilter';
import { assertStaffOfShop } from '../shared/shopAuthorization';
import { ReplyToCommentInput, SubmitCommentInput } from './types';

const MAX_TEXT_LENGTH = 500;

/**
 * Comentarios sobre el servicio (spec 7.2) y su moderación (spec 7.3). Se
 * modera EN el propio callable, antes de escribir el documento — a
 * diferencia de un trigger onCreate, así nunca existe una ventana donde un
 * comentario ofensivo quede públicamente visible mientras se revisa.
 */
export class CommentService {
  async submitComment(input: SubmitCommentInput): Promise<{ commentId: string; status: 'published' | 'rejected' }> {
    const text = input.text.trim();
    if (text.length === 0 || text.length > MAX_TEXT_LENGTH) {
      throw new HttpsError('invalid-argument', `El comentario debe tener entre 1 y ${MAX_TEXT_LENGTH} caracteres.`);
    }

    const firestore = getFirestore();
    const appointmentRef = firestore.collection('appointments').doc(input.appointmentId);
    const commentRef = firestore.collection('comments').doc(input.appointmentId);

    const appointmentSnap = await appointmentRef.get();
    if (!appointmentSnap.exists) throw new HttpsError('not-found', 'La cita no existe.');
    const appointment = appointmentSnap.data()!;

    if (appointment.clientId !== input.clientId) {
      throw new HttpsError('permission-denied', 'Solo el cliente de esa cita puede comentarla.');
    }
    if (appointment.paid !== true || appointment.status !== 'completed') {
      throw new HttpsError('failed-precondition', 'Solo se puede comentar una reserva pagada y completada.');
    }

    const existingComment = await commentRef.get();
    if (existingComment.exists) {
      throw new HttpsError('already-exists', 'Ya dejaste un comentario en esta cita.');
    }

    const status = containsOffensiveContent(text) ? 'rejected' : 'published';

    await commentRef.set({
      appointmentId: input.appointmentId,
      barbershopId: appointment.barbershopId,
      barberId: appointment.barberId,
      clientId: input.clientId,
      clientName: appointment.clientName ?? '',
      text,
      photoUrl: input.photoUrl,
      status,
      createdAt: FieldValue.serverTimestamp(),
      replyText: null,
      replyAt: null,
      repliedByBarberId: null,
    });

    return { commentId: commentRef.id, status };
  }

  /**
   * El personal de la barbería responde (spec 7.2: "ya sea dirigido a él o
   * a la barbería en general" — por eso cualquier miembro del personal de
   * ESA barbería puede responder, no solo el barbero atendido). También
   * pasa por el mismo filtro de moderación: una respuesta ofensiva no
   * debería poder publicarse.
   */
  async replyToComment(input: ReplyToCommentInput): Promise<void> {
    const replyText = input.replyText.trim();
    if (replyText.length === 0 || replyText.length > MAX_TEXT_LENGTH) {
      throw new HttpsError('invalid-argument', `La respuesta debe tener entre 1 y ${MAX_TEXT_LENGTH} caracteres.`);
    }
    if (containsOffensiveContent(replyText)) {
      throw new HttpsError('invalid-argument', 'La respuesta contiene lenguaje inapropiado.');
    }

    const firestore = getFirestore();
    const commentRef = firestore.collection('comments').doc(input.commentId);
    const commentSnap = await commentRef.get();
    if (!commentSnap.exists) throw new HttpsError('not-found', 'El comentario no existe.');
    const comment = commentSnap.data()!;

    await assertStaffOfShop(input.barberId, comment.barbershopId as string);

    if (comment.status !== 'published') {
      throw new HttpsError('failed-precondition', 'Solo se puede responder a un comentario publicado.');
    }
    if (comment.replyText) {
      throw new HttpsError('already-exists', 'Este comentario ya tiene una respuesta.');
    }

    await commentRef.update({
      replyText,
      replyAt: FieldValue.serverTimestamp(),
      repliedByBarberId: input.barberId,
    });
  }
}
