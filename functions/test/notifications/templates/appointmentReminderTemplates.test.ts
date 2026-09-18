import { renderAppointmentReminder } from '../../../src/notifications/templates/appointmentReminderTemplates';
import { NotificationTone } from '../../../src/notifications/types';

const TONES: NotificationTone[] = ['formal', 'normal', 'friendly', 'informal'];
const DATA = { serviceName: 'Corte clásico', barbershopName: 'BarberFlow Centro', time: '15:00' };

describe('renderAppointmentReminder', () => {
  it.each(TONES)('1h en tono %s incluye servicio, barbería y hora, con título y cuerpo no vacíos', (tone) => {
    const { title, body } = renderAppointmentReminder('1h', tone, DATA);
    expect(title.trim().length).toBeGreaterThan(0);
    expect(body).toContain(DATA.serviceName);
    expect(body).toContain(DATA.barbershopName);
    expect(body).toContain(DATA.time);
  });

  it.each(TONES)('15m en tono %s incluye servicio, barbería y hora, con título y cuerpo no vacíos', (tone) => {
    const { title, body } = renderAppointmentReminder('15m', tone, DATA);
    expect(title.trim().length).toBeGreaterThan(0);
    expect(body).toContain(DATA.serviceName);
    expect(body).toContain(DATA.barbershopName);
    expect(body).toContain(DATA.time);
  });

  it('el texto de 1h es distinto del de 15m para el mismo tono', () => {
    const oneHour = renderAppointmentReminder('1h', 'normal', DATA);
    const fifteenMin = renderAppointmentReminder('15m', 'normal', DATA);
    expect(oneHour.body).not.toBe(fifteenMin.body);
  });
});
