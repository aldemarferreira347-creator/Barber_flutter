import 'package:cloud_firestore/cloud_firestore.dart';

/// Calificación por estrellas de una cita pagada y completada (spec 7.1).
/// El id del documento ES el appointmentId (una sola calificación por
/// cita) — solo la escribe el backend vía submitAppointmentRating.
class Rating {
  final String appointmentId;
  final String barbershopId;
  final String barberId;
  final String clientId;
  final int barberStars;
  final int shopStars;
  final DateTime? createdAt;

  const Rating({
    required this.appointmentId,
    required this.barbershopId,
    required this.barberId,
    required this.clientId,
    required this.barberStars,
    required this.shopStars,
    this.createdAt,
  });

  factory Rating.fromMap(String appointmentId, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    return Rating(
      appointmentId: appointmentId,
      barbershopId: map['barbershopId'] as String? ?? '',
      barberId: map['barberId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      barberStars: (map['barberStars'] as num?)?.toInt() ?? 0,
      shopStars: (map['shopStars'] as num?)?.toInt() ?? 0,
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
    );
  }
}
