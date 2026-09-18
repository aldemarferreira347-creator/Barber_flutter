import { CommentService } from '../../src/ratings/commentService';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  FieldValue: { serverTimestamp: () => 'SERVER_TIMESTAMP' },
  Timestamp: class FakeTimestamp {},
}));

function seedAppointment(id: string, overrides: Partial<Record<string, unknown>> = {}) {
  fakeFirestore.seed(`appointments/${id}`, {
    barbershopId: 'shop1',
    barberId: 'barber1',
    clientId: 'client1',
    clientName: 'Ana',
    status: 'completed',
    paid: true,
    ...overrides,
  });
}

beforeEach(() => {
  fakeFirestore.reset();
  fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1', name: 'BarberFlow Centro' });
  fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
  fakeFirestore.seed('users/owner1', { role: 'owner' });
});

describe('CommentService.submitComment', () => {
  it('publica un comentario normal, con foto opcional', async () => {
    seedAppointment('appt1');
    const service = new CommentService();

    const result = await service.submitComment({ appointmentId: 'appt1', clientId: 'client1', text: 'Excelente corte', photoUrl: 'https://x/1.jpg' });

    expect(result.status).toBe('published');
    const comment = (await fakeFirestore.doc('comments/appt1').get()).data()!;
    expect(comment).toMatchObject({
      text: 'Excelente corte',
      photoUrl: 'https://x/1.jpg',
      status: 'published',
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
    });
  });

  it('rechaza (no publica) un comentario con lenguaje ofensivo', async () => {
    seedAppointment('appt1');
    const service = new CommentService();

    const result = await service.submitComment({ appointmentId: 'appt1', clientId: 'client1', text: 'El barbero es un idiota', photoUrl: null });

    expect(result.status).toBe('rejected');
    const comment = (await fakeFirestore.doc('comments/appt1').get()).data()!;
    expect(comment.status).toBe('rejected');
  });

  it('rechaza comentar una cita ajena', async () => {
    seedAppointment('appt1');
    const service = new CommentService();
    await expect(
      service.submitComment({ appointmentId: 'appt1', clientId: 'otherClient', text: 'Buen servicio', photoUrl: null }),
    ).rejects.toThrow('Solo el cliente');
  });

  it('rechaza comentar una cita sin pago o no completada', async () => {
    seedAppointment('unpaid', { paid: false });
    const service = new CommentService();
    await expect(
      service.submitComment({ appointmentId: 'unpaid', clientId: 'client1', text: 'Buen servicio', photoUrl: null }),
    ).rejects.toThrow('pagada y completada');
  });

  it('rechaza texto vacío', async () => {
    seedAppointment('appt1');
    const service = new CommentService();
    await expect(service.submitComment({ appointmentId: 'appt1', clientId: 'client1', text: '   ', photoUrl: null })).rejects.toThrow(
      'entre 1 y',
    );
  });

  it('rechaza un segundo comentario en la misma cita', async () => {
    seedAppointment('appt1');
    const service = new CommentService();
    await service.submitComment({ appointmentId: 'appt1', clientId: 'client1', text: 'Buen servicio', photoUrl: null });
    await expect(
      service.submitComment({ appointmentId: 'appt1', clientId: 'client1', text: 'Otro comentario', photoUrl: null }),
    ).rejects.toThrow('Ya dejaste');
  });
});

describe('CommentService.replyToComment', () => {
  async function seedPublishedComment(id: string, overrides: Partial<Record<string, unknown>> = {}) {
    fakeFirestore.seed(`comments/${id}`, {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      text: 'Buen servicio',
      status: 'published',
      replyText: null,
      ...overrides,
    });
  }

  it('el barbero de esa barbería responde un comentario publicado', async () => {
    await seedPublishedComment('c1');
    const service = new CommentService();

    await service.replyToComment({ commentId: 'c1', barberId: 'barber1', replyText: 'Gracias por tu visita' });

    const comment = (await fakeFirestore.doc('comments/c1').get()).data()!;
    expect(comment.replyText).toBe('Gracias por tu visita');
    expect(comment.repliedByBarberId).toBe('barber1');
  });

  it('el dueño de la barbería también puede responder (comentario dirigido a la barbería en general)', async () => {
    await seedPublishedComment('c1');
    const service = new CommentService();
    await service.replyToComment({ commentId: 'c1', barberId: 'owner1', replyText: 'Gracias por la confianza' });
    const comment = (await fakeFirestore.doc('comments/c1').get()).data()!;
    expect(comment.replyText).toBe('Gracias por la confianza');
  });

  it('rechaza a personal de otra barbería', async () => {
    fakeFirestore.seed('users/stranger1', { role: 'barber', barbershopId: 'shop2' });
    await seedPublishedComment('c1');
    const service = new CommentService();
    await expect(service.replyToComment({ commentId: 'c1', barberId: 'stranger1', replyText: 'Hola' })).rejects.toThrow('permiso');
  });

  it('rechaza una respuesta con lenguaje ofensivo', async () => {
    await seedPublishedComment('c1');
    const service = new CommentService();
    await expect(
      service.replyToComment({ commentId: 'c1', barberId: 'barber1', replyText: 'Eres un idiota' }),
    ).rejects.toThrow('inapropiado');
  });

  it('rechaza responder un comentario rechazado por moderación', async () => {
    await seedPublishedComment('c1', { status: 'rejected' });
    const service = new CommentService();
    await expect(service.replyToComment({ commentId: 'c1', barberId: 'barber1', replyText: 'Hola' })).rejects.toThrow('publicado');
  });

  it('rechaza responder dos veces', async () => {
    await seedPublishedComment('c1', { replyText: 'Ya respondido' });
    const service = new CommentService();
    await expect(service.replyToComment({ commentId: 'c1', barberId: 'barber1', replyText: 'Otra' })).rejects.toThrow(
      'ya tiene una respuesta',
    );
  });

  it('rechaza un comentario inexistente', async () => {
    const service = new CommentService();
    await expect(service.replyToComment({ commentId: 'ghost', barberId: 'barber1', replyText: 'Hola' })).rejects.toThrow('no existe');
  });
});
