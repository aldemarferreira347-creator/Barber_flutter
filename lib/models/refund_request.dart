import 'package:cloud_firestore/cloud_firestore.dart';

enum RefundRequestStatus { pending, approved, rejected }

extension RefundRequestStatusX on RefundRequestStatus {
  String get value => name;

  String get label => switch (this) {
    RefundRequestStatus.pending => 'Pendiente de revisión',
    RefundRequestStatus.approved => 'Aprobada',
    RefundRequestStatus.rejected => 'Rechazada',
  };

  static RefundRequestStatus fromValue(String value) {
    return RefundRequestStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RefundRequestStatus.pending,
    );
  }
}

/// Solicitud de cancelación con justificación de una cita pagada (spec 6.3,
/// 6.5). Solo la escribe el backend (requestAppointmentRefund /
/// resolveAppointmentRefund) — el cliente y el dueño únicamente la leen.
class RefundRequest {
  final String id;
  final String appointmentId;
  final String barbershopId;
  final String clientId;
  final String reason;
  final String? purchaseId;
  final List<int>? purchaseItemIndexes;
  final RefundRequestStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const RefundRequest({
    required this.id,
    required this.appointmentId,
    required this.barbershopId,
    required this.clientId,
    required this.reason,
    required this.status,
    this.purchaseId,
    this.purchaseItemIndexes,
    this.createdAt,
    this.resolvedAt,
  });

  factory RefundRequest.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final resolvedAtValue = map['resolvedAt'];
    return RefundRequest(
      id: id,
      appointmentId: map['appointmentId'] as String? ?? '',
      barbershopId: map['barbershopId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      purchaseId: map['purchaseId'] as String?,
      purchaseItemIndexes: (map['purchaseItemIndexes'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      status: RefundRequestStatusX.fromValue(
        map['status'] as String? ?? 'pending',
      ),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      resolvedAt: resolvedAtValue is Timestamp
          ? resolvedAtValue.toDate()
          : null,
    );
  }
}
