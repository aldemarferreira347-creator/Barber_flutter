import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de una compra de productos (spec 10.4/10.5). No confundir con
/// [PaymentIntentStatus], que es el estado del PAGO asociado.
enum PurchaseStatus { pendingPayment, pendingClaim, claimed, expired, paymentFailed }

extension PurchaseStatusX on PurchaseStatus {
  String get value => switch (this) {
    PurchaseStatus.pendingPayment => 'pending_payment',
    PurchaseStatus.pendingClaim => 'pending_claim',
    PurchaseStatus.claimed => 'claimed',
    PurchaseStatus.expired => 'expired',
    PurchaseStatus.paymentFailed => 'payment_failed',
  };

  String get label => switch (this) {
    PurchaseStatus.pendingPayment => 'Procesando pago',
    PurchaseStatus.pendingClaim => 'Lista para reclamar',
    PurchaseStatus.claimed => 'Reclamada',
    PurchaseStatus.expired => 'Vencida',
    PurchaseStatus.paymentFailed => 'Pago fallido',
  };

  static PurchaseStatus fromValue(String value) {
    return switch (value) {
      'pending_claim' => PurchaseStatus.pendingClaim,
      'claimed' => PurchaseStatus.claimed,
      'expired' => PurchaseStatus.expired,
      'payment_failed' => PurchaseStatus.paymentFailed,
      _ => PurchaseStatus.pendingPayment,
    };
  }
}

class PurchaseItem {
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final bool refunded;

  const PurchaseItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.refunded = false,
  });

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      refunded: map['refunded'] as bool? ?? false,
    );
  }
}

/// Compra de productos (purchases/{id}). Solo la escribe el backend
/// (createPurchase/claimPurchase/refundPurchaseItems) — el cliente únicamente la lee.
class Purchase {
  final String id;
  final String barbershopId;
  final String buyerId;
  final String? appointmentId;
  final List<PurchaseItem> items;
  final double totalAmount;
  final String? paymentId;
  final String? claimCode;
  final PurchaseStatus status;
  final DateTime? createdAt;
  final DateTime? claimedAt;
  final DateTime? expiresAt;

  const Purchase({
    required this.id,
    required this.barbershopId,
    required this.buyerId,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.appointmentId,
    this.paymentId,
    this.claimCode,
    this.createdAt,
    this.claimedAt,
    this.expiresAt,
  });

  factory Purchase.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final claimedAtValue = map['claimedAt'];
    final expiresAtValue = map['expiresAt'];
    return Purchase(
      id: id,
      barbershopId: map['barbershopId'] as String? ?? '',
      buyerId: map['buyerId'] as String? ?? '',
      appointmentId: map['appointmentId'] as String?,
      items:
          (map['items'] as List?)?.map((e) => PurchaseItem.fromMap(Map<String, dynamic>.from(e as Map))).toList() ??
          const [],
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      paymentId: map['paymentId'] as String?,
      claimCode: map['claimCode'] as String?,
      status: PurchaseStatusX.fromValue(map['status'] as String? ?? 'pending_payment'),
      createdAt: createdAtValue is Timestamp ? createdAtValue.toDate() : null,
      claimedAt: claimedAtValue is Timestamp ? claimedAtValue.toDate() : null,
      expiresAt: expiresAtValue is Timestamp ? expiresAtValue.toDate() : null,
    );
  }
}
