import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, accepted, rejected, postponed, completed, cancelled }

extension AppointmentStatusX on AppointmentStatus {
  String get value => name;

  static AppointmentStatus fromValue(String value) {
    return AppointmentStatus.values.firstWhere((s) => s.name == value, orElse: () => AppointmentStatus.pending);
  }

  String get label => switch (this) {
    AppointmentStatus.pending => 'Pendiente',
    AppointmentStatus.accepted => 'Aceptada',
    AppointmentStatus.rejected => 'Rechazada',
    AppointmentStatus.postponed => 'Aplazada',
    AppointmentStatus.completed => 'Completada',
    AppointmentStatus.cancelled => 'Cancelada',
  };
}

/// Un cambio de fecha registrado sobre una cita pagada (spec 6.4): vincula
/// la nueva fecha con la reserva original.
class RescheduleEntry {
  final DateTime from;
  final DateTime to;

  const RescheduleEntry({required this.from, required this.to});

  factory RescheduleEntry.fromMap(Map<String, dynamic> map) {
    final fromValue = map['from'];
    final toValue = map['to'];
    return RescheduleEntry(
      from: fromValue is Timestamp ? fromValue.toDate() : DateTime.now(),
      to: toValue is Timestamp ? toValue.toDate() : DateTime.now(),
    );
  }
}

class Appointment {
  final String id;
  final String barbershopId;
  final String barberId;
  final String barberName;
  final String clientId;
  final String clientName;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final int durationMinutes;
  final DateTime date;
  final AppointmentStatus status;
  final DateTime? createdAt;

  /// Reserva pagada (spec 6.1): bloquea el horario y solo la crea
  /// bookPaidAppointment en el backend — nunca un create() directo.
  final bool paid;
  final String? paymentId;
  final List<RescheduleEntry> rescheduleHistory;

  const Appointment({
    required this.id,
    required this.barbershopId,
    required this.barberId,
    required this.barberName,
    required this.clientId,
    required this.clientName,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.durationMinutes,
    required this.date,
    this.status = AppointmentStatus.pending,
    this.createdAt,
    this.paid = false,
    this.paymentId,
    this.rescheduleHistory = const [],
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    final dateValue = map['date'];
    final createdAtValue = map['createdAt'];
    return Appointment(
      id: id,
      barbershopId: map['barbershopId'] as String? ?? '',
      barberId: map['barberId'] as String? ?? '',
      barberName: map['barberName'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? '',
      serviceId: map['serviceId'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      servicePrice: (map['servicePrice'] as num?)?.toDouble() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      date: dateValue is Timestamp ? dateValue.toDate() : DateTime.now(),
      status: AppointmentStatusX.fromValue(map['status'] as String? ?? 'pending'),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      paid: map['paid'] as bool? ?? false,
      paymentId: map['paymentId'] as String?,
      rescheduleHistory:
          (map['rescheduleHistory'] as List?)
              ?.map((e) => RescheduleEntry.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barbershopId': barbershopId,
      'barberId': barberId,
      'barberName': barberName,
      'clientId': clientId,
      'clientName': clientName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'durationMinutes': durationMinutes,
      'date': Timestamp.fromDate(date),
      'status': status.value,
      'createdAt': createdAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt!),
      'paid': paid,
    };
  }
}
