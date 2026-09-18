import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { CommentService } from '../../ratings/commentService';

const MAX_TEXT_LENGTH = 500;

interface SubmitCommentRequest {
  appointmentId: unknown;
  text: unknown;
  photoUrl?: unknown;
}

function validate(data: SubmitCommentRequest) {
  const appointmentId = data.appointmentId;
  const text = data.text;
  const photoUrl = data.photoUrl ?? null;

  if (typeof appointmentId !== 'string' || appointmentId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'appointmentId es obligatorio.');
  }
  if (typeof text !== 'string' || text.trim().length === 0 || text.length > MAX_TEXT_LENGTH) {
    throw new HttpsError('invalid-argument', `text es obligatorio (máx. ${MAX_TEXT_LENGTH} caracteres).`);
  }
  if (photoUrl !== null && (typeof photoUrl !== 'string' || photoUrl.trim().length === 0)) {
    throw new HttpsError('invalid-argument', 'photoUrl inválido.');
  }

  return { appointmentId, text, photoUrl: photoUrl as string | null };
}

export function createSubmitAppointmentCommentHandler(service: CommentService = new CommentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    return service.submitComment({ ...input, clientId: request.auth.uid });
  });
}

export const submitAppointmentComment = createSubmitAppointmentCommentHandler();
