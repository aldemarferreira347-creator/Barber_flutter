import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/purchase.dart';
import '../repositories/purchase_repository.dart';

class CloudPurchaseService implements PurchaseRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  CloudPurchaseService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _firestore.collection('purchases');

  @override
  Future<String> createPurchase({
    required String barbershopId,
    required List<PurchaseItemInput> items,
    String? appointmentId,
  }) async {
    final result = await _functions
        .httpsCallable('createPurchase')
        .call<Map<String, dynamic>>({
          'barbershopId': barbershopId,
          'items': items
              .map((i) => {'productId': i.productId, 'quantity': i.quantity})
              .toList(),
          'appointmentId': appointmentId,
        });
    return result.data['id'] as String;
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
  Future<void> claimPurchase(String purchaseId) {
    return _functions.httpsCallable('claimPurchase').call<void>({
      'purchaseId': purchaseId,
    });
  }

  @override
  Future<void> refundItems({
    required String purchaseId,
    required List<int> itemIndexes,
  }) {
    return _functions.httpsCallable('refundPurchaseItems').call<void>({
      'purchaseId': purchaseId,
      'itemIndexes': itemIndexes,
    });
  }
}
