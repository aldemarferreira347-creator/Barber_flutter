import { AppointmentService } from '../../src/appointments/appointmentService';
import { PaymentGatewayAdapter } from '../../src/payments/types';
import { createFakeFirestore } from '../testUtils/fakeFirestore';

const fakeFirestore = createFakeFirestore();

// jest.mock se hoistea por encima de TODO lo demás en este archivo (import
// y const/class incluidos), así que el factory no puede leer ningún
// binding externo de forma inmediata — solo cerrar sobre él en una función
// que se llame después (getFirestore), o requerir/declarar todo inline.
jest.mock('firebase-admin/firestore', () => ({
  getFirestore: () => fakeFirestore,
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- ver comentario arriba
  FieldValue: (require('../testUtils/fakeFirestore') as typeof import('../testUtils/fakeFirestore')).createFakeFieldValue(),
  Timestamp: class FakeTimestamp {},
}));

function fakeGateway(overrides: Partial<PaymentGatewayAdapter> = {}): jest.Mocked<PaymentGatewayAdapter> {
  return {
    requestPayment: jest.fn().mockResolvedValue('payment1'),
    refund: jest.fn().mockResolvedValue(undefined),
    ...overrides,
  } as jest.Mocked<PaymentGatewayAdapter>;
}

function seedService(shopId: string, serviceId: string, data: Record<string, unknown>) {
  fakeFirestore.seed(`barbershops/${shopId}/services/${serviceId}`, data);
}

beforeEach(() => fakeFirestore.reset());

describe('AppointmentService.bookPaidAppointment', () => {
  const baseInput = {
    clientId: 'client1',
    clientName: 'Ana',
    barbershopId: 'shop1',
    barberId: 'barber1',
    barberName: 'Beto',
    serviceId: 'svc1',
    date: new Date('2026-06-01T15:00:00Z'),
  };

  it('reserva el horario, cobra y guarda el paymentId', async () => {
    seedService('shop1', 'svc1', { name: 'Corte', price: 20000, durationMinutes: 30, active: true });
    const gateway = fakeGateway();
    const service = new AppointmentService(gateway);

    const id = await service.bookPaidAppointment(baseInput);

    expect(gateway.requestPayment).toHaveBeenCalledWith(
      expect.objectContaining({ payerId: 'client1', amount: 20000, category: 'appointment', relatedId: id }),
    );
    const snapshot = await fakeFirestore.doc(`appointments/${id}`).get();
    expect(snapshot.data()!.paid).toBe(true);
    expect(snapshot.data()!.paymentId).toBe('payment1');
    expect(snapshot.data()!.status).toBe('pending');
  });

  it('el segundo cliente que intenta el mismo horario es rechazado', async () => {
    seedService('shop1', 'svc1', { name: 'Corte', price: 20000, durationMinutes: 30, active: true });
    const service = new AppointmentService(fakeGateway());

    await service.bookPaidAppointment(baseInput);

    await expect(service.bookPaidAppointment({ ...baseInput, clientId: 'client2', clientName: 'Bea' })).rejects.toThrow(
      'ya no está disponible',
    );
  });

  it('el mismo horario con OTRO barbero sí se puede reservar', async () => {
    seedService('shop1', 'svc1', { name: 'Corte', price: 20000, durationMinutes: 30, active: true });
    const service = new AppointmentService(fakeGateway());

    await service.bookPaidAppointment(baseInput);

    await expect(
      service.bookPaidAppointment({ ...baseInput, clientId: 'client2', barberId: 'barber2', barberName: 'Caro' }),
    ).resolves.toBeTruthy();
  });

  it('rechaza un servicio inactivo o inexistente', async () => {
    seedService('shop1', 'svc1', { name: 'Corte', price: 20000, durationMinutes: 30, active: false });
    const service = new AppointmentService(fakeGateway());

    await expect(service.bookPaidAppointment(baseInput)).rejects.toThrow('ya no está disponible');
  });

  it('si el pago falla, cancela la cita y libera el horario para otros', async () => {
    seedService('shop1', 'svc1', { name: 'Corte', price: 20000, durationMinutes: 30, active: true });
    const failingGateway = fakeGateway({ requestPayment: jest.fn().mockRejectedValue(new Error('rechazado')) });
    const service = new AppointmentService(failingGateway);

    await expect(service.bookPaidAppointment(baseInput)).rejects.toThrow('rechazado');

    // Al fallar el pago de la primera, un segundo cliente SÍ debe poder tomar ese horario.
    const okService = new AppointmentService(fakeGateway());
    await expect(okService.bookPaidAppointment({ ...baseInput, clientId: 'client2', clientName: 'Bea' })).resolves.toBeTruthy();
  });
});

describe('AppointmentService.postponePaidAppointment', () => {
  const oldDate = new Date('2026-06-01T15:00:00Z');
  const newDate = new Date('2026-06-02T15:00:00Z');

  async function seedPaidAppointment(id: string, overrides: Record<string, unknown> = {}) {
    fakeFirestore.seed(`appointments/${id}`, {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      date: oldDate,
      status: 'accepted',
      paid: true,
      paymentId: 'payment1',
      rescheduleHistory: [],
      ...overrides,
    });
    await fakeFirestore.doc(`appointmentSlots/barber1_${oldDate.toISOString().slice(0, 16)}`).set({ appointmentId: id });
  }

  it('mueve la cita, libera el horario viejo y ocupa el nuevo, con historial', async () => {
    await seedPaidAppointment('appt1');
    const service = new AppointmentService(fakeGateway());

    await service.postponePaidAppointment('appt1', 'client1', newDate);

    const appointment = (await fakeFirestore.doc('appointments/appt1').get()).data()!;
    expect(appointment.status).toBe('postponed');
    expect(appointment.date).toEqual(newDate);
    expect(appointment.rescheduleHistory).toEqual([{ from: oldDate, to: newDate }]);

    const oldSlot = await fakeFirestore.doc(`appointmentSlots/barber1_${oldDate.toISOString().slice(0, 16)}`).get();
    expect(oldSlot.exists).toBe(false);
    const newSlot = await fakeFirestore.doc(`appointmentSlots/barber1_${newDate.toISOString().slice(0, 16)}`).get();
    expect(newSlot.exists).toBe(true);
  });

  it('rechaza si el nuevo horario ya está ocupado', async () => {
    await seedPaidAppointment('appt1');
    await fakeFirestore.doc(`appointmentSlots/barber1_${newDate.toISOString().slice(0, 16)}`).set({ appointmentId: 'other' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'client1', newDate)).rejects.toThrow('no está disponible');
  });

  it('rechaza a quien no es cliente, ni el barbero asignado, ni dueño de la barbería', async () => {
    await seedPaidAppointment('appt1');
    fakeFirestore.seed('users/stranger1', { role: 'client' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'stranger1', newDate)).rejects.toThrow('Solo el dueño');
  });

  it('el barbero asignado también puede posponerla', async () => {
    await seedPaidAppointment('appt1');
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'barber1', newDate)).resolves.toBeUndefined();
  });

  it('el dueño de la barbería también puede posponerla', async () => {
    await seedPaidAppointment('appt1');
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'owner1', newDate)).resolves.toBeUndefined();
  });

  it('rechaza una cita sin pago', async () => {
    await seedPaidAppointment('appt1', { paid: false });
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'client1', newDate)).rejects.toThrow('no está pagada');
  });

  it('rechaza posponer una cita ya cancelada o completada', async () => {
    await seedPaidAppointment('appt1', { status: 'cancelled' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.postponePaidAppointment('appt1', 'client1', newDate)).rejects.toThrow('No se puede posponer');
  });
});

describe('AppointmentService.requestRefund / resolveRefundRequest', () => {
  async function seedPaidAppointment(id: string, overrides: Record<string, unknown> = {}) {
    fakeFirestore.seed(`appointments/${id}`, {
      barbershopId: 'shop1',
      barberId: 'barber1',
      clientId: 'client1',
      date: new Date('2026-06-01T15:00:00Z'),
      status: 'accepted',
      paid: true,
      paymentId: 'payment1',
      ...overrides,
    });
  }

  it('crea la solicitud pendiente con la justificación', async () => {
    await seedPaidAppointment('appt1');
    const service = new AppointmentService(fakeGateway());

    const id = await service.requestRefund({
      appointmentId: 'appt1',
      clientId: 'client1',
      reason: 'Tuve una emergencia',
      purchaseId: null,
      purchaseItemIndexes: null,
    });

    const request = (await fakeFirestore.doc(`refundRequests/${id}`).get()).data()!;
    expect(request.status).toBe('pending');
    expect(request.barbershopId).toBe('shop1');
  });

  it('rechaza una justificación vacía', async () => {
    await seedPaidAppointment('appt1');
    const service = new AppointmentService(fakeGateway());

    await expect(
      service.requestRefund({ appointmentId: 'appt1', clientId: 'client1', reason: '  ', purchaseId: null, purchaseItemIndexes: null }),
    ).rejects.toThrow('justificación');
  });

  it('rechaza si quien solicita no es el cliente de la cita', async () => {
    await seedPaidAppointment('appt1');
    const service = new AppointmentService(fakeGateway());

    await expect(
      service.requestRefund({ appointmentId: 'appt1', clientId: 'stranger1', reason: 'x', purchaseId: null, purchaseItemIndexes: null }),
    ).rejects.toThrow('Solo el cliente');
  });

  it('el dueño aprueba: reembolsa el pago, cancela la cita y libera el horario', async () => {
    await seedPaidAppointment('appt1');
    await fakeFirestore.doc('appointmentSlots/barber1_2026-06-01T15:00').set({ appointmentId: 'appt1' });
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    fakeFirestore.seed('refundRequests/req1', {
      appointmentId: 'appt1',
      barbershopId: 'shop1',
      clientId: 'client1',
      status: 'pending',
      purchaseId: null,
      purchaseItemIndexes: null,
    });
    const gateway = fakeGateway();
    const service = new AppointmentService(gateway);

    await service.resolveRefundRequest('req1', 'owner1', true);

    expect(gateway.refund).toHaveBeenCalledWith('payment1');
    expect((await fakeFirestore.doc('appointments/appt1').get()).data()!.status).toBe('cancelled');
    expect((await fakeFirestore.doc('appointmentSlots/barber1_2026-06-01T15:00').get()).exists).toBe(false);
    expect((await fakeFirestore.doc('refundRequests/req1').get()).data()!.status).toBe('approved');
  });

  it('el dueño rechaza: no reembolsa ni cancela nada', async () => {
    await seedPaidAppointment('appt1');
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    fakeFirestore.seed('refundRequests/req1', {
      appointmentId: 'appt1',
      barbershopId: 'shop1',
      clientId: 'client1',
      status: 'pending',
    });
    const gateway = fakeGateway();
    const service = new AppointmentService(gateway);

    await service.resolveRefundRequest('req1', 'owner1', false);

    expect(gateway.refund).not.toHaveBeenCalled();
    expect((await fakeFirestore.doc('appointments/appt1').get()).data()!.status).toBe('accepted');
    expect((await fakeFirestore.doc('refundRequests/req1').get()).data()!.status).toBe('rejected');
  });

  it('un barbero (no dueño) no puede aprobar el reembolso', async () => {
    await seedPaidAppointment('appt1');
    fakeFirestore.seed('users/barber1', { role: 'barber', barbershopId: 'shop1' });
    fakeFirestore.seed('refundRequests/req1', { appointmentId: 'appt1', barbershopId: 'shop1', clientId: 'client1', status: 'pending' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.resolveRefundRequest('req1', 'barber1', true)).rejects.toThrow('Solo el dueño');
  });

  it('rechaza resolver una solicitud ya resuelta', async () => {
    fakeFirestore.seed('refundRequests/req1', { appointmentId: 'appt1', barbershopId: 'shop1', clientId: 'client1', status: 'approved' });
    const service = new AppointmentService(fakeGateway());

    await expect(service.resolveRefundRequest('req1', 'owner1', true)).rejects.toThrow('ya fue resuelta');
  });

  it('al aprobar, también reembolsa los ítems de un Purchase vinculado si se indicaron', async () => {
    await seedPaidAppointment('appt1');
    fakeFirestore.seed('users/owner1', { role: 'owner' });
    fakeFirestore.seed('barbershops/shop1', { ownerId: 'owner1' });
    fakeFirestore.seed('purchases/purchase1', {
      paymentId: 'paymentX',
      items: [{ productId: 'p1', productName: 'Cera', unitPrice: 15000, quantity: 1, refunded: false }],
    });
    fakeFirestore.seed('refundRequests/req1', {
      appointmentId: 'appt1',
      barbershopId: 'shop1',
      clientId: 'client1',
      status: 'pending',
      purchaseId: 'purchase1',
      purchaseItemIndexes: [0],
    });
    const gateway = fakeGateway();
    const service = new AppointmentService(gateway);

    await service.resolveRefundRequest('req1', 'owner1', true);

    expect(gateway.refund).toHaveBeenCalledWith('payment1'); // el pago de la cita
    expect(gateway.refund).toHaveBeenCalledWith('paymentX', 15000); // el pago de la compra vinculada
    const purchase = (await fakeFirestore.doc('purchases/purchase1').get()).data()!;
    expect((purchase.items as Array<{ refunded: boolean }>)[0].refunded).toBe(true);
  });
});
