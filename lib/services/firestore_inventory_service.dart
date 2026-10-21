import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/purchase.dart';
import '../models/stock_movement.dart';
import '../repositories/inventory_repository.dart';
import '../utils/parse_docs.dart';
import '../utils/shared_stream.dart';

class FirestoreInventoryService implements InventoryRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreInventoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Tope de la lista de movimientos (las pantallas no paginan).
  static const _maxItems = 100;

  /// Tope de una sola entrada o salida: evita errores de dedo.
  static const maxQuantity = 10000;

  CollectionReference<Map<String, dynamic>> get _movements =>
      _firestore.collection('stockMovements');

  DocumentReference<Map<String, dynamic>> _product(
    String barbershopId,
    String productId,
  ) => _firestore
      .collection('barbershops')
      .doc(barbershopId)
      .collection('products')
      .doc(productId);

  @override
  Stream<List<StockMovement>> watchMovements(String barbershopId) {
    return _shared.of<List<StockMovement>>('watchMovements:$barbershopId', () {
      return _movements
          .where('barbershopId', isEqualTo: barbershopId)
          .orderBy('createdAt', descending: true)
          .limit(_maxItems)
          .snapshots()
          .map(
            (snapshot) => parseDocs(
              snapshot.docs,
              (doc) => StockMovement.fromMap(doc.id, barbershopId, doc.data()),
            ),
          );
    });
  }

  Future<String> _userName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return (doc.data()?['name'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> registerMovement({
    required String barbershopId,
    required String productId,
    required StockMovementType type,
    required int quantity,
    required StockReason reason,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');
    if (quantity <= 0 || quantity > maxQuantity) {
      throw Exception('La cantidad debe estar entre 1 y $maxQuantity.');
    }
    if (reason.type != type) {
      throw Exception('El motivo no corresponde a una ${type.label}.');
    }
    final userName = await _userName(uid);
    final trimmedNote = note?.trim();
    final movementRef = _movements.doc();

    await _firestore.runTransaction((tx) async {
      final productRef = _product(barbershopId, productId);
      final snap = await tx.get(productRef);
      final data = snap.data();
      if (!snap.exists || data == null) {
        throw Exception('Ese producto ya no existe.');
      }
      final current = (data['stock'] as num?)?.toInt();
      final previous = current ?? 0;
      if (type == StockMovementType.outbound) {
        if (current == null) {
          throw const InsufficientStockException(
            'Este producto aún no tiene inventario. Registra primero una '
            'entrada con las unidades que hay.',
          );
        }
        if (quantity > current) {
          throw InsufficientStockException(
            'Solo quedan $current unidades; no puedes sacar $quantity.',
          );
        }
      }
      final after = type == StockMovementType.inbound
          ? previous + quantity
          : previous - quantity;

      tx.set(movementRef, {
        'barbershopId': barbershopId,
        'productId': productId,
        'productName': data['name'] ?? '',
        'type': type.value,
        'quantity': quantity,
        'reason': reason.key,
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
        'previousStock': previous,
        'stockAfter': after,
        'byUserId': uid,
        'byUserName': userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // `lastMovementId` amarra este cambio de stock a su movimiento: las
      // reglas solo dejan a un barbero tocar el stock si hay un registro que
      // lo explique.
      tx.update(productRef, {'stock': after, 'lastMovementId': movementRef.id});
    });
  }

  @override
  Future<int> registerPurchaseDelivery(Purchase purchase) async {
    var discounted = 0;
    for (final item in purchase.items) {
      if (item.refunded || item.quantity <= 0) continue;
      final snap = await _product(purchase.barbershopId, item.productId).get();
      final stock = (snap.data()?['stock'] as num?)?.toInt();
      if (stock == null || stock <= 0) continue;
      final quantity = item.quantity > stock ? stock : item.quantity;
      try {
        await registerMovement(
          barbershopId: purchase.barbershopId,
          productId: item.productId,
          type: StockMovementType.outbound,
          quantity: quantity,
          reason: StockReason.claim,
          note: 'Compra ${purchase.id}',
        );
        discounted++;
      } on InsufficientStockException {
        // Otro movimiento se llevó el stock entre la lectura y la escritura.
      }
    }
    return discounted;
  }
}
