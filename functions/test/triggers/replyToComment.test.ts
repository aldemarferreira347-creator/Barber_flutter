import { HttpsError } from 'firebase-functions/v2/https';

import { createReplyToCommentHandler } from '../../src/triggers/https/replyToComment';
import { CommentService } from '../../src/ratings/commentService';

function fakeService(): jest.Mocked<Pick<CommentService, 'replyToComment'>> {
  return { replyToComment: jest.fn().mockResolvedValue(undefined) };
}

function callAs(handler: ReturnType<typeof createReplyToCommentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const VALID_PAYLOAD = { commentId: 'c1', replyText: 'Gracias por tu visita' };

describe('replyToComment callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createReplyToCommentHandler(service as unknown as CommentService);
    await expect(callAs(handler, undefined, VALID_PAYLOAD)).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin commentId', { ...VALID_PAYLOAD, commentId: '' }],
    ['sin replyText', { ...VALID_PAYLOAD, replyText: '' }],
    ['replyText muy largo', { ...VALID_PAYLOAD, replyText: 'a'.repeat(501) }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createReplyToCommentHandler(service as unknown as CommentService);
    await expect(callAs(handler, 'barber1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.replyToComment).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como barberId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createReplyToCommentHandler(service as unknown as CommentService);

    const result = await callAs(handler, 'barber1', VALID_PAYLOAD);

    expect(result).toEqual({ success: true });
    expect(service.replyToComment).toHaveBeenCalledWith({ commentId: 'c1', replyText: 'Gracias por tu visita', barberId: 'barber1' });
  });
});
