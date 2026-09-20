import 'package:cloud_firestore/cloud_firestore.dart';

import 'day_schedule.dart';

enum PaymentStatus { ok, overdue, blocked }

extension PaymentStatusX on PaymentStatus {
  String get value => name;

  static PaymentStatus fromValue(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PaymentStatus.ok,
    );
  }
}

/// Revisión del administrador sobre la solicitud de registro (spec 12.1):
/// toda barbería nace 'pending' y solo el admin la pasa a 'approved' o
/// 'rejected' — nunca el propio dueño.
enum BarbershopApprovalStatus { pending, approved, rejected }

extension BarbershopApprovalStatusX on BarbershopApprovalStatus {
  String get value => name;

  static BarbershopApprovalStatus fromValue(String value) {
    return BarbershopApprovalStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BarbershopApprovalStatus.pending,
    );
  }
}

class Barbershop {
  final String id;
  final String name;
  final String ownerId;
  final String? address;
  final GeoPoint? location;
  final String? phone;
  final String? email;
  final String? description;
  final String? photoUrl;

  /// Visibilidad/operación general: si está en false, la barbería y sus
  /// barberos quedan bloqueados y desaparecen del catálogo (spec 12.6),
  /// sea porque aún no fue aprobada o porque se bloqueó por mensualidad.
  final bool active;
  final BarbershopApprovalStatus approvalStatus;
  final PaymentStatus paymentStatus;
  final DateTime? paymentDueDate;
  final Map<String, DaySchedule> schedule;

  /// Suma y cantidad de calificaciones recibidas (spec 7.1) — solo los
  /// escribe submitAppointmentRating en el backend. El promedio ya incluye
  /// el descuento obligatorio por cierres de tienda (spec 3.4).
  final int ratingSum;
  final int ratingCount;

  const Barbershop({
    required this.id,
    required this.name,
    required this.ownerId,
    this.address,
    this.location,
    this.phone,
    this.email,
    this.description,
    this.photoUrl,
    this.active = false,
    this.approvalStatus = BarbershopApprovalStatus.pending,
    this.paymentStatus = PaymentStatus.ok,
    this.paymentDueDate,
    this.schedule = const {},
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  /// 0 si nadie ha calificado todavía — nunca un promedio inventado.
  double get averageRating => ratingCount == 0 ? 0 : ratingSum / ratingCount;

  /// Solo aparece en el catálogo del cliente si el admin ya la aprobó y no
  /// está bloqueada (spec 12.1/12.6).
  bool get isVisibleInCatalog =>
      active && approvalStatus == BarbershopApprovalStatus.approved;

  factory Barbershop.fromMap(String id, Map<String, dynamic> map) {
    final dueDateValue = map['paymentDueDate'];
    return Barbershop(
      id: id,
      name: map['name'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      address: map['address'] as String?,
      location: map['location'] as GeoPoint?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      description: map['description'] as String?,
      photoUrl: map['photoUrl'] as String?,
      active: map['active'] as bool? ?? true,
      approvalStatus: BarbershopApprovalStatusX.fromValue(
        map['approvalStatus'] as String? ??
            BarbershopApprovalStatus.pending.value,
      ),
      paymentStatus: PaymentStatusX.fromValue(
        map['paymentStatus'] as String? ?? PaymentStatus.ok.value,
      ),
      paymentDueDate: dueDateValue is Timestamp ? dueDateValue.toDate() : null,
      schedule: weekScheduleFromMap(map['schedule'] as Map<String, dynamic>?),
      ratingSum: (map['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'address': address,
      'location': location,
      'phone': phone,
      'email': email,
      'description': description,
      'photoUrl': photoUrl,
      'active': active,
      'approvalStatus': approvalStatus.value,
      'paymentStatus': paymentStatus.value,
      'paymentDueDate': paymentDueDate == null
          ? null
          : Timestamp.fromDate(paymentDueDate!),
      'schedule': schedule.isEmpty
          ? weekScheduleToMap(weekScheduleFromMap(null))
          : weekScheduleToMap(schedule),
    };
  }
}
