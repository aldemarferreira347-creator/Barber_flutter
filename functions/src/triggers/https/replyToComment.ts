import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { CommentService } from '../../ratings/commentService';

const MAX_TEXT_LENGTH = 500;

interface ReplyToCommentRequest {
  commentId: unknown;
  replyText: unknown;
}

function validate(data: ReplyToCommentRequest) {
  const commentId = data.commentId;
  const replyText = data.replyText;

  if (typeof commentId !== 'string' || commentId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'commentId es obligatorio.');
  }
  if (typeof replyText !== 'string' || replyText.trim().length === 0 || replyText.length > MAX_TEXT_LENGTH) {
    throw new HttpsError('invalid-argument', `replyText es obligatorio (máx. ${MAX_TEXT_LENGTH} caracteres).`);
  }

  return { commentId, replyText };
}

export function createReplyToCommentHandler(service: CommentService = new CommentService()) {
  return onCall(async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const input = validate(request.data ?? {});
    await service.replyToComment({ ...input, barberId: request.auth.uid });
    return { success: true };
  });
}

export const replyToComment = createReplyToCommentHandler();
