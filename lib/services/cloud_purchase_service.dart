import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/purchase.dart';
import '../repositories/purchase_repository.dart';
import 'claim_code.dart';

// Nombre histórico (antes llamaba a createPurchase/claimPurchase/
// refundPurchaseItems, Cloud Functions) — sin plan Blaze escribe Firestore
// directo. Los precios SIEMPRE se recalculan desde el catálogo real (ver
// firestore.rules), nunca se confía en lo que mande el cliente.
//
// maxItems bajó de 20 (límite original del backend) a 5: para validar en
// las reglas que cada precio/nombre de producto es real hace falta un
// get() por ítem dentro de la propia regla, y Firestore limita cuántos
// get()/exists() caben en la evaluación de una sola escritura. Hoy la
// única pantalla de compra (BuyProductView) manda un solo ítem, así que 5
// deja margen de sobra para un futuro carrito sin arriesgar ese límite.
class CloudPurchaseService implements PurchaseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Duration _simulatedApprovalDelay;

  static const maxItems = 5;
  static const _claimWindow = Duration(hours: 24);

  CloudPurchaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Duration? simulatedApprovalDelay,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _simulatedApprovalDelay =
           simulatedApprovalDelay ?? const Duration(milliseconds: 1500);

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _firestore.collection('purchases');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  @override
  Future<String> createPurchase({
    required String barbershopId,
    required List<PurchaseItemInput> items,
    String? appointmentId,
  }) async {
    final buyerId = _auth.currentUser?.uid;
    if (buyerId == null) throw Exception('Debes iniciar sesión.');
    if (items.isEmpty || items.length > maxItems) {
      throw Exception('La compra debe incluir entre 1 y $maxItems productos.');
    }

    final productsRef = _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('products');

    final resolvedItems = <Map<String, dynamic>>[];
    for (final requested in items) {
      if (requested.quantity <= 0) {
        throw Exception('Cantidad inválida para ${requested.productId}.');
      }
      final productSnap = await productsRef.doc(requested.productId).get();
      final product = productSnap.data();
      if (!productSnap.exists || product == null || product['active'] != true) {
        throw Exception(
          'El producto ${requested.productId} ya no está disponible.',
        );
      }
      resolvedItems.add({
        'productId': requested.productId,
        'productName': product['name'],
        'unitPrice': product['price'],
        'quantity': requested.quantity,
        'refunded': false,
      });
    }

    final totalAmount = resolvedItems.fold<num>(
      0,
      (total, item) =>
          total + (item['unitPrice'] as num) * (item['quantity'] as int),
    );

    final purchaseRef = _purchases.doc();
    await purchaseRef.set({
      'barbershopId': barbershopId,
      'buyerId': buyerId,
      'appointmentId': appointmentId,
      'items': resolvedItems,
      'totalAmount': totalAmount,
      'paymentId': null,
      'claimCode': null,
      'status': 'pending_payment',
      'createdAt': FieldValue.serverTimestamp(),
      'claimedAt': null,
      'expiresAt': null,
    });

    // Igual que en el resto de la migración: el pago simulado (mismo patrón
    // que SimulatedNequiGateway) se crea aparte y se aprueba tras un breve
    // delay; recién entonces la compra pasa a 'pending_claim' con su código.
    final paymentRef = _payments.doc();
    try {
      await paymentRef.set({
        'payerId': buyerId,
        'amount': totalAmount,
        'category': 'product',
        'relatedId': purchaseRef.id,
        'description': 'Compra de productos en barbershops/$barbershopId',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'refundedAmount': null,
      });

      await Future<void>.delayed(_simulatedApprovalDelay);
      await paymentRef.update({
        'status': 'approved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      await purchaseRef.update({
        'paymentId': paymentRef.id,
        'claimCode': generateClaimCode(),
        'status': 'pending_claim',
        'expiresAt': Timestamp.fromDate(DateTime.now().add(_claimWindow)),
      });
    } catch (e) {
      await purchaseRef.update({'status': 'payment_failed'});
      rethrow;
    }

    return purchaseRef.id;
  }

  @override
  Stream<Purchase?> watchPurchase(String purchaseId) {
    return _purchases.doc(purchaseId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return Purchase.fromMap(doc.id, data);
    });
  }

  @override
  Stream<List<Purchase>> watchByBuyer(String buyerId) {
    return _purchases
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Purchase.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<Purchase>> watchByBarbershop(String barbershopId) {
    return _purchases
        .where('barbershopId', isEqualTo: barbershopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Purchase.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<Purchase?> findByClaimCode({
    required String barbershopId,
    required String claimCode,
  }) async {
    final snapshot = await _purchases
        .where('barbershopId', isEqualTo: barbershopId)
        .where('claimCode', isEqualTo: claimCode.trim().toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Purchase.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  @override
  Future<void> claimPurchase(String purchaseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');

    final ref = _purchases.doc(purchaseId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) throw Exception('La compra no existe.');
    if (data['status'] != 'pending_claim') {
      throw Exception(
        'La compra no está lista para reclamar (status: ${data['status']}).',
      );
    }

    await ref.update({
      'status': 'claimed',
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> refundItems({
    required String purchaseId,
    required List<int> itemIndexes,
  }) async {
    if (itemIndexes.isEmpty) {
      throw Exception('Selecciona al menos un ítem para reembolsar.');
    }

    final ref = _purchases.doc(purchaseId);
    final snap = await ref.get();
    final data = snap.data();
    if (!snap.exists || data == null) throw Exception('La compra no existe.');

    final items = List<Map<String, dynamic>>.from(
      (data['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );

    for (final index in itemIndexes) {
      if (index < 0 || index >= items.length) {
        throw Exception('Índice de ítem inválido: $index.');
      }
      if (items[index]['refunded'] == true) {
        throw Exception('El ítem $index ya fue reembolsado.');
      }
    }
    final paymentId = data['paymentId'] as String?;
    if (paymentId == null) {
      throw Exception('La compra no tiene un pago asociado.');
    }

    final refundAmount = itemIndexes.fold<num>(
      0,
      (total, index) =>
          total +
          (items[index]['unitPrice'] as num) *
              (items[index]['quantity'] as num),
    );

    // Igual que el backend: primero se reembolsa el pago, luego se marcan
    // los ítems — si la compra vuelve a intentar reembolsarse después, la
    // regla de payments/{id} ya no deja pasar un segundo 'refunded' (mismo
    // límite que ya tenía SimulatedNequiGateway.refund del lado servidor).
    await _payments.doc(paymentId).update({
      'status': 'refunded',
      'refundedAmount': refundAmount,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    final updatedItems = [
      for (var i = 0; i < items.length; i++)
        if (itemIndexes.contains(i))
          {...items[i], 'refunded': true}
        else
          items[i],
    ];
    await ref.update({'items': updatedItems});
  }
}
