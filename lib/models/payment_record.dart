import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de una solicitud de pago individual — no confundir con
/// [PaymentStatus] de Barbershop, que es el estado de la MENSUALIDAD.
enum PaymentIntentStatus { pending, approved, rejected, refunded }

extension PaymentIntentStatusX on PaymentIntentStatus {
  String get value => name;

  static PaymentIntentStatus fromValue(String value) {
    return PaymentIntentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentIntentStatus.pending,
    );
  }
}

/// Qué se está pagando. Determina cómo se interpreta [PaymentRecord.relatedId].
enum PaymentCategory { appointment, product, subscription }

extension PaymentCategoryX on PaymentCategory {
  String get value => name;

  static PaymentCategory fromValue(String value) {
    return PaymentCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => PaymentCategory.appointment,
    );
  }
}

/// Medio por el que se devuelve un reembolso. Como el cobro es manual
/// (transferencia Nequi verificada por una persona), la devolución también:
/// quien reembolsa dice cómo lo hizo.
enum RefundMethod { nequi, cash }

extension RefundMethodX on RefundMethod {
  String get value => name;

  String get label => switch (this) {
    RefundMethod.nequi => 'Nequi',
    RefundMethod.cash => 'Efectivo',
  };

  static RefundMethod? fromValue(String? value) {
    for (final method in RefundMethod.values) {
      if (method.name == value) return method;
    }
    return null;
  }
}

/// Referencia del comprobante Nequi que el pagador escribe: 4 a 30
/// letras, números o guiones. Espejo de la validación de firestore.rules.
final _referencePattern = RegExp(r'^[A-Za-z0-9-]{4,30}$');

/// Limpia lo que pegó el usuario (espacios alrededor) para validarlo.
String normalizePaymentReference(String raw) => raw.trim();

/// Mensaje de error para un campo de referencia, o null si es válida.
String? validatePaymentReference(String? raw) {
  final value = normalizePaymentReference(raw ?? '');
  if (value.isEmpty) return 'Escribe la referencia del comprobante';
  if (!_referencePattern.hasMatch(value)) {
    return 'Usa de 4 a 30 letras, números o guiones, sin espacios';
  }
  return null;
}

/// Registro de un pago (payments/{id}). Cobro Nequi manual: el pagador lo
/// crea `pending` con la referencia de su comprobante y quien recibió el
/// dinero (personal de la barbería o, para la mensualidad, el admin) lo
/// confirma o rechaza.
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

  /// Referencia del comprobante Nequi que escribió el pagador.
  final String? reference;

  /// Uid de quien confirmó o rechazó el pago.
  final String? resolvedBy;
  final RefundMethod? refundMethod;

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
    this.reference,
    this.resolvedBy,
    this.refundMethod,
  });

  /// Documento de un pago nuevo: siempre `pending`, con el comprobante.
  /// Lo comparten las citas, las compras y la mensualidad para que las tres
  /// escriban exactamente lo que firestore.rules acepta.
  static Map<String, dynamic> newPendingMap({
    required String payerId,
    required num amount,
    required PaymentCategory category,
    required String relatedId,
    required String reference,
    String? description,
  }) => {
    'payerId': payerId,
    'amount': amount,
    'category': category.value,
    'relatedId': relatedId,
    'description': description,
    'status': PaymentIntentStatus.pending.value,
    'createdAt': FieldValue.serverTimestamp(),
    'resolvedAt': null,
    'refundedAmount': null,
    'reference': normalizePaymentReference(reference),
    'method': 'nequi',
  };

  bool get isPending => status == PaymentIntentStatus.pending;

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final resolvedAtValue = map['resolvedAt'];
    return PaymentRecord(
      id: id,
      payerId: map['payerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: PaymentCategoryX.fromValue(
        map['category'] as String? ?? PaymentCategory.appointment.value,
      ),
      relatedId: map['relatedId'] as String? ?? '',
      description: map['description'] as String?,
      status: PaymentIntentStatusX.fromValue(
        map['status'] as String? ?? PaymentIntentStatus.pending.value,
      ),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      resolvedAt: resolvedAtValue is Timestamp
          ? resolvedAtValue.toDate()
          : null,
      refundedAmount: (map['refundedAmount'] as num?)?.toDouble(),
      reference: map['reference'] as String?,
      resolvedBy: map['resolvedBy'] as String?,
      refundMethod: RefundMethodX.fromValue(map['refundMethod'] as String?),
    );
  }
}
