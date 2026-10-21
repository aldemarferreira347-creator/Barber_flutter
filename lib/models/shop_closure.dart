import 'package:cloud_firestore/cloud_firestore.dart';

/// Cierre de una barbería por un evento externo (`barbershops/{id}.closure`).
/// [until] nulo significa que NO hay fecha de regreso: la barbería queda
/// cerrada hasta que su dueño la reabra.
class ShopClosure {
  final String id;
  final DateTime from;
  final DateTime? until;
  final String reason;

  const ShopClosure({
    required this.id,
    required this.from,
    required this.reason,
    this.until,
  });

  bool get isIndefinite => until == null;

  /// La barbería está cerrada en el instante [moment].
  bool isActiveAt(DateTime moment) =>
      !moment.isBefore(from) && (until == null || moment.isBefore(until!));

  /// Un horario [start]-[end] se cruza con el cierre.
  bool overlaps(DateTime start, DateTime end) =>
      end.isAfter(from) && (until == null || start.isBefore(until!));

  /// Hasta cuándo, para mostrar: "hasta vie 5 oct · 10:00" o "hasta nuevo
  /// aviso".
  String untilLabel(String Function(DateTime) format) =>
      until == null ? 'hasta nuevo aviso' : 'hasta ${format(until!)}';

  static ShopClosure? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final from = raw['from'];
    if (from is! Timestamp) return null;
    final until = raw['until'];
    return ShopClosure(
      id: raw['closureId'] as String? ?? '',
      from: from.toDate(),
      until: until is Timestamp ? until.toDate() : null,
      reason: raw['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'closureId': id,
    'from': Timestamp.fromDate(from),
    'until': until == null ? null : Timestamp.fromDate(until!),
    'reason': reason,
  };
}
