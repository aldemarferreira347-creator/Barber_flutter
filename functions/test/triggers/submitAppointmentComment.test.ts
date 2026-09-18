import { HttpsError } from 'firebase-functions/v2/https';

import { createSubmitAppointmentCommentHandler } from '../../src/triggers/https/submitAppointmentComment';
import { CommentService } from '../../src/ratings/commentService';

function fakeService(): jest.Mocked<Pick<CommentService, 'submitComment'>> {
  return { submitComment: jest.fn().mockResolvedValue({ commentId: 'appt1', status: 'published' }) };
}

function callAs(handler: ReturnType<typeof createSubmitAppointmentCommentHandler>, uid: string | undefined, data: Record<string, unknown>) {
  return handler.run({ data, auth: uid ? ({ uid } as never) : undefined } as never);
}

const VALID_PAYLOAD = { appointmentId: 'appt1', text: 'Excelente corte' };

describe('submitAppointmentComment callable', () => {
  it('rechaza si no hay sesión', async () => {
    const service = fakeService();
    const handler = createSubmitAppointmentCommentHandler(service as unknown as CommentService);
    await expect(callAs(handler, undefined, VALID_PAYLOAD)).rejects.toBeInstanceOf(HttpsError);
  });

  it.each([
    ['sin appointmentId', { ...VALID_PAYLOAD, appointmentId: '' }],
    ['sin text', { ...VALID_PAYLOAD, text: '' }],
    ['text muy largo', { ...VALID_PAYLOAD, text: 'a'.repeat(501) }],
    ['photoUrl inválido', { ...VALID_PAYLOAD, photoUrl: '' }],
  ] as const)('rechaza payload inválido: %s', async (_label, payload) => {
    const service = fakeService();
    const handler = createSubmitAppointmentCommentHandler(service as unknown as CommentService);
    await expect(callAs(handler, 'client1', payload)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect(service.submitComment).not.toHaveBeenCalled();
  });

  it('usa el uid autenticado como clientId y delega en el servicio', async () => {
    const service = fakeService();
    const handler = createSubmitAppointmentCommentHandler(service as unknown as CommentService);

    const result = await callAs(handler, 'client1', { ...VALID_PAYLOAD, photoUrl: 'https://x/1.jpg' });

    expect(result).toEqual({ commentId: 'appt1', status: 'published' });
    expect(service.submitComment).toHaveBeenCalledWith({
      appointmentId: 'appt1',
      text: 'Excelente corte',
      photoUrl: 'https://x/1.jpg',
      clientId: 'client1',
    });
  });

  it('photoUrl es opcional', async () => {
    const service = fakeService();
    const handler = createSubmitAppointmentCommentHandler(service as unknown as CommentService);

    await callAs(handler, 'client1', VALID_PAYLOAD);

    expect(service.submitComment).toHaveBeenCalledWith({
      appointmentId: 'appt1',
      text: 'Excelente corte',
      photoUrl: null,
      clientId: 'client1',
    });
  });
});
