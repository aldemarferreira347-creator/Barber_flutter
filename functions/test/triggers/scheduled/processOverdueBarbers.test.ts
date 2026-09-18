import { createProcessOverdueBarbersHandler } from '../../../src/triggers/scheduled/processOverdueBarbers';
import { BarberAvailabilityService } from '../../../src/barbers/barberAvailabilityService';

function fakeService(result: { barbersAffected: number; appointmentsPostponed: number }) {
  return { processOverdueBarbers: jest.fn().mockResolvedValue(result) } as unknown as BarberAvailabilityService;
}

describe('processOverdueBarbers scheduled function', () => {
  it('llama a processOverdueBarbers en cada corrida', async () => {
    const service = fakeService({ barbersAffected: 1, appointmentsPostponed: 2 });
    const handler = createProcessOverdueBarbersHandler(service);

    await handler.run({} as never);

    expect(service.processOverdueBarbers).toHaveBeenCalledTimes(1);
  });

  it('no falla cuando no hay barberos vencidos', async () => {
    const service = fakeService({ barbersAffected: 0, appointmentsPostponed: 0 });
    const handler = createProcessOverdueBarbersHandler(service);

    await expect(handler.run({} as never)).resolves.toBeUndefined();
  });
});
