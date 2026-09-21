/// Id determinístico de appointmentSlots/{id}: mismo barbero + mismo minuto
/// de inicio => mismo id. Crearlo con un create() atómico dentro de una
/// transacción es lo que garantiza que solo un cliente gane ese horario
/// cuando dos lo intentan al mismo tiempo (spec 6.2).
///
/// Debe coincidir exactamente con slotId() en
/// functions/src/appointments/slotId.ts (mismo formato "yyyy-MM-ddTHH:mm"
/// en UTC) — si algún día el proyecto sube a Blaze y se retoman las Cloud
/// Functions, los slots creados por uno y otro lado deben ser el mismo id.
String appointmentSlotId(String barberId, DateTime date) {
  final minuteIso = date.toUtc().toIso8601String().substring(0, 16);
  return '${barberId}_$minuteIso';
}
