import '../models/appointment.dart';

abstract class AppointmentRepository {
  Future<String> create(Appointment appointment);

  Stream<List<Appointment>> watchByClient(String clientId);

  Stream<List<Appointment>> watchByBarber(String barberId);

  Stream<List<Appointment>> watchByBarbershop(String barbershopId);

  Future<void> setStatus(String id, AppointmentStatus status);

  Future<void> reschedule(String id, DateTime newDate);
}
