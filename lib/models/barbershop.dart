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
  final bool active;
  final PaymentStatus paymentStatus;
  final DateTime? paymentDueDate;
  final Map<String, DaySchedule> schedule;

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
    this.active = true,
    this.paymentStatus = PaymentStatus.ok,
    this.paymentDueDate,
    this.schedule = const {},
  });

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
      paymentStatus: PaymentStatusX.fromValue(map['paymentStatus'] as String? ?? PaymentStatus.ok.value),
      paymentDueDate: dueDateValue is Timestamp ? dueDateValue.toDate() : null,
      schedule: weekScheduleFromMap(map['schedule'] as Map<String, dynamic>?),
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
      'paymentStatus': paymentStatus.value,
      'paymentDueDate': paymentDueDate == null ? null : Timestamp.fromDate(paymentDueDate!),
      'schedule': schedule.isEmpty ? weekScheduleToMap(weekScheduleFromMap(null)) : weekScheduleToMap(schedule),
    };
  }
}
