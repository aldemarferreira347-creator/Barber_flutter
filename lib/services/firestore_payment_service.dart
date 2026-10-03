import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/payment_record.dart';
import '../repositories/payment_repository.dart';
import '../utils/shared_stream.dart';

class FirestorePaymentService implements PaymentRepository {
  final _shared = SharedStreams();

  final FirebaseFirestore _firestore;

  FirestorePaymentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('payments');

  /// Tope de cada lista (las pantallas no paginan).
  static const _maxPayments = 50;

  static int _newestFirst(PaymentRecord a, PaymentRecord b) =>
      (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());

  @override
  Stream<PaymentRecord?> watchPayment(String paymentId) {
    return _shared.of<PaymentRecord?>('watchPayment:$paymentId', () {
      return _payments.doc(paymentId).snapshots().map((doc) {
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        return PaymentRecord.fromMap(doc.id, data);
      });
    });
  }

  @override
  Stream<List<PaymentRecord>> watchPendingSubscriptions() {
    return _shared.of<List<PaymentRecord>>('watchPendingSubscriptions', () {
      // Consulta solo con igualdades (no pide índice compuesto); se ordena
      // en el cliente porque los pendientes son pocos.
      return _payments
          .where('category', isEqualTo: PaymentCategory.subscription.value)
          .where('status', isEqualTo: PaymentIntentStatus.pending.value)
          .limit(_maxPayments)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => PaymentRecord.fromMap(doc.id, doc.data()))
                    .toList()
                  ..sort((a, b) => _newestFirst(b, a)),
          );
    });
  }

  @override
  Stream<List<PaymentRecord>> watchSubscriptionPayments({
    required String payerId,
    required String shopId,
  }) {
    return _shared.of<List<PaymentRecord>>(
      'watchSubscriptionPayments:$payerId:$shopId',
      () {
        return _payments
            .where('payerId', isEqualTo: payerId)
            .where('category', isEqualTo: PaymentCategory.subscription.value)
            .where('relatedId', isEqualTo: shopId)
            .limit(_maxPayments)
            .snapshots()
            .map(
              (snapshot) =>
                  snapshot.docs
                      .map((doc) => PaymentRecord.fromMap(doc.id, doc.data()))
                      .toList()
                    ..sort(_newestFirst),
            );
      },
    );
  }
}
