import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/payment_record.dart';
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
//
// Cobro Nequi manual: el comprador transfiere y registra la referencia; la
// compra queda 'pending_payment' hasta que el personal de la barbería
// verifique el dinero (confirmPayment), que es cuando se genera el código
// de reclamo y empieza el plazo de 24 h.
class CloudPurchaseService implements PurchaseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const maxItems = 5;

  CloudPurchaseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _firestore.collection('purchases');

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  @override
  Future<String> createPurchase({
    required String barbershopId,
    required List<PurchaseItemInput> items,
    required String reference,
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

    // El pago Nequi se registra pendiente, con la referencia del comprobante,
    // y se enlaza a la compra. Si algo falla en el camino, la compra queda
    // 'payment_failed' en vez de colgada.
    final paymentRef = _payments.doc();
    try {
      await paymentRef.set(
        PaymentRecord.newPendingMap(
          payerId: buyerId,
          amount: totalAmount,
          category: PaymentCategory.product,
          relatedId: purchaseRef.id,
          description: 'Compra de productos en barbershops/$barbershopId',
          reference: reference,
        ),
      );
      await purchaseRef.update({'paymentId': paymentRef.id});
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

  /// Tope de cada lista: lo más reciente (las pantallas no paginan).
  static const _maxListItems = 100;

  @override
  Stream<List<Purchase>> watchByBuyer(String buyerId) {
    return _purchases
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .limit(_maxListItems)
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
        .limit(_maxListItems)
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
    final purchase = Purchase.fromMap(snap.id, data);
    if (purchase.isExpired) {
      throw Exception(
        'Esta compra venció: pasaron más de 24 horas desde el pago.',
      );
    }
    if (purchase.status != PurchaseStatus.pendingClaim) {
      throw Exception('La compra no está lista para reclamar.');
    }

    await ref.update({
      'status': 'claimed',
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lee la compra y su pago pendiente.
  Future<({Purchase purchase, DocumentReference<Map<String, dynamic>> payment})>
  _awaitingPayment(String purchaseId) async {
    final snap = await _purchases.doc(purchaseId).get();
    final data = snap.data();
    if (!snap.exists || data == null) throw Exception('La compra no existe.');
    final purchase = Purchase.fromMap(snap.id, data);
    final paymentId = purchase.paymentId;
    if (purchase.status != PurchaseStatus.pendingPayment || paymentId == null) {
      throw Exception('Esta compra no tiene un pago por verificar.');
    }
    final paymentRef = _payments.doc(paymentId);
    final paymentSnap = await paymentRef.get();
    if (paymentSnap.data()?['status'] != PaymentIntentStatus.pending.value) {
      throw Exception('El pago de esta compra ya fue resuelto.');
    }
    return (purchase: purchase, payment: paymentRef);
  }

  Map<String, dynamic> _resolution(PaymentIntentStatus status) => {
    'status': status.value,
    'resolvedAt': FieldValue.serverTimestamp(),
    'resolvedBy': _auth.currentUser?.uid,
  };

  @override
  Future<void> confirmPayment(String purchaseId) async {
    final pending = await _awaitingPayment(purchaseId);
    // Una sola escritura: el pago queda verificado y la compra pasa a ser
    // reclamable con su código y 24 h de plazo.
    final batch = _firestore.batch();
    batch.update(pending.payment, _resolution(PaymentIntentStatus.approved));
    batch.update(_purchases.doc(purchaseId), {
      'status': 'pending_claim',
      'claimCode': generateClaimCode(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(kClaimWindow)),
    });
    await batch.commit();
  }

  @override
  Future<void> rejectPayment(String purchaseId) async {
    final pending = await _awaitingPayment(purchaseId);
    final batch = _firestore.batch();
    batch.update(pending.payment, _resolution(PaymentIntentStatus.rejected));
    batch.update(_purchases.doc(purchaseId), {'status': 'payment_failed'});
    await batch.commit();
  }
}
