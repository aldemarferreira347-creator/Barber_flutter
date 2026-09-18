import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/payment_record.dart';
import '../repositories/payment_repository.dart';

/// Wrapper delgado: la lógica real de pago (simulada hoy, Nequi real
/// mañana) vive en el backend (functions/src/payments) — este cliente solo
/// invoca las Cloud Functions callable y lee payments/{id} en vivo.
class NequiPaymentGateway implements PaymentGateway {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  NequiPaymentGateway({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> requestPayment({
    required double amount,
    required PaymentCategory category,
    required String relatedId,
    String? description,
  }) async {
    final result = await _functions.httpsCallable('requestPayment').call<Map<String, dynamic>>({
      'amount': amount,
      'category': category.value,
      'relatedId': relatedId,
      'description': description,
    });
    return result.data['id'] as String;
  }

  @override
  Stream<PaymentRecord?> watchPayment(String paymentId) {
    return _firestore.collection('payments').doc(paymentId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return PaymentRecord.fromMap(doc.id, data);
    });
  }

  @override
  Future<void> refund(String paymentId, {double? amount}) {
    return _functions.httpsCallable('refundPayment').call<void>({
      'paymentId': paymentId,
      'amount': ?amount,
    });
  }
}
