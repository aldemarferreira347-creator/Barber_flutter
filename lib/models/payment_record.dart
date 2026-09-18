import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de una solicitud de pago individual — no confundir con
/// [PaymentStatus] de Barbershop, que es el estado de la MENSUALIDAD.
enum PaymentIntentStatus { pending, approved, rejected, refunded }

extension PaymentIntentStatusX on PaymentIntentStatus {
  String get value => name;

  static PaymentIntentStatus fromValue(String value) {
    return PaymentIntentStatus.values.firstWhere((s) => s.name == value, orElse: () => PaymentIntentStatus.pending);
  }
}

/// Qué se está pagando. Determina cómo se interpreta [PaymentRecord.relatedId].
enum PaymentCategory { appointment, product, subscription }

extension PaymentCategoryX on PaymentCategory {
  String get value => name;

  static PaymentCategory fromValue(String value) {
    return PaymentCategory.values.firstWhere((c) => c.name == value, orElse: () => PaymentCategory.appointment);
  }
}

/// Registro de un pago (payments/{id}). Solo lo escribe el backend
/// (Cloud Function con Admin SDK) — el cliente únicamente lo lee.
class PaymentRecord {
  final String id;
  final String payerId;
  final double amount;
  final PaymentCategory category;
  final String relatedId;
  final String? description;
  final PaymentIntentStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final double? refundedAmount;

  const PaymentRecord({
    required this.id,
    required this.payerId,
    required this.amount,
    required this.category,
    required this.relatedId,
    required this.status,
    this.description,
    this.createdAt,
    this.resolvedAt,
    this.refundedAmount,
  });

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final resolvedAtValue = map['resolvedAt'];
    return PaymentRecord(
      id: id,
      payerId: map['payerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: PaymentCategoryX.fromValue(map['category'] as String? ?? PaymentCategory.appointment.value),
      relatedId: map['relatedId'] as String? ?? '',
      description: map['description'] as String?,
      status: PaymentIntentStatusX.fromValue(map['status'] as String? ?? PaymentIntentStatus.pending.value),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      resolvedAt: resolvedAtValue is Timestamp ? resolvedAtValue.toDate() : null,
      refundedAmount: (map['refundedAmount'] as num?)?.toDouble(),
    );
  }
}
