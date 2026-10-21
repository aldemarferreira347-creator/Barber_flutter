import 'package:cloud_firestore/cloud_firestore.dart';

/// Entrada o salida de unidades de un producto.
enum StockMovementType { inbound, outbound }

extension StockMovementTypeX on StockMovementType {
  String get value => this == StockMovementType.inbound ? 'in' : 'out';

  String get label => this == StockMovementType.inbound ? 'Entrada' : 'Salida';

  static StockMovementType fromValue(String? value) =>
      value == 'in' ? StockMovementType.inbound : StockMovementType.outbound;
}

/// Motivo de un movimiento. La clave es lo que se guarda; la etiqueta, lo que
/// se muestra.
enum StockReason {
  restock('restock', 'Reposición', StockMovementType.inbound),
  customerReturn('return', 'Devolución', StockMovementType.inbound),
  adjustUp('adjust_up', 'Ajuste de conteo', StockMovementType.inbound),
  sale('sale', 'Venta en el local', StockMovementType.outbound),
  claim('claim', 'Entrega de compra', StockMovementType.outbound),
  waste('waste', 'Pérdida o daño', StockMovementType.outbound),
  adjustDown('adjust_down', 'Ajuste de conteo', StockMovementType.outbound);

  final String key;
  final String label;
  final StockMovementType type;

  const StockReason(this.key, this.label, this.type);

  static StockReason fromKey(String? key) => StockReason.values.firstWhere(
    (r) => r.key == key,
    orElse: () => StockReason.adjustDown,
  );

  /// Motivos que puede elegir una persona en el formulario (la entrega de
  /// una compra la registra la app sola).
  static List<StockReason> selectable(StockMovementType type) => [
    for (final r in StockReason.values)
      if (r.type == type && r != StockReason.claim) r,
  ];
}

/// Registro de inventario: quién metió o sacó cuántas unidades de qué
/// producto y cómo quedó el stock (`barbershops/{id}/stockMovements`).
class StockMovement {
  final String id;
  final String barbershopId;
  final String productId;
  final String productName;
  final StockMovementType type;
  final int quantity;
  final StockReason reason;
  final String? note;
  final int previousStock;
  final int stockAfter;
  final String byUserId;
  final String byUserName;
  final DateTime? createdAt;

  const StockMovement({
    required this.id,
    required this.barbershopId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.previousStock,
    required this.stockAfter,
    required this.byUserId,
    required this.byUserName,
    this.note,
    this.createdAt,
  });

  factory StockMovement.fromMap(
    String id,
    String barbershopId,
    Map<String, dynamic> map,
  ) {
    final created = map['createdAt'];
    return StockMovement(
      id: id,
      barbershopId: barbershopId,
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      type: StockMovementTypeX.fromValue(map['type'] as String?),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      reason: StockReason.fromKey(map['reason'] as String?),
      note: map['note'] as String?,
      previousStock: (map['previousStock'] as num?)?.toInt() ?? 0,
      stockAfter: (map['stockAfter'] as num?)?.toInt() ?? 0,
      byUserId: map['byUserId'] as String? ?? '',
      byUserName: map['byUserName'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
