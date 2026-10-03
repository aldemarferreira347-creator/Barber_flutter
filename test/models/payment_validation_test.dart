import 'package:barber/models/barbershop.dart';
import 'package:barber/models/payment_record.dart';
import 'package:barber/models/purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatePaymentReference (espejo de firestore.rules)', () {
    test('acepta de 4 a 30 letras, números o guiones', () {
      for (final ok in ['M1234567', 'ab-12', 'A1B2', '1' * 30, ' M1234567 ']) {
        expect(validatePaymentReference(ok), isNull, reason: ok);
      }
    });

    test('rechaza vacío, muy corto, muy largo o con símbolos', () {
      for (final bad in [
        '',
        '   ',
        null,
        'abc',
        '1' * 31,
        'con espacio',
        'M123;DROP',
        'ñandú12',
      ]) {
        expect(validatePaymentReference(bad), isNotNull, reason: '$bad');
      }
    });

    test('normalizePaymentReference recorta espacios', () {
      expect(normalizePaymentReference('  M123456 '), 'M123456');
    });
  });

  group('Nequi', () {
    test('validateNequiPhone exige 10 dígitos que empiecen en 3', () {
      expect(validateNequiPhone('3001234567'), isNull);
      expect(validateNequiPhone('300 123 4567'), isNull);
      expect(validateNequiPhone('+57 300 123 4567'), isNull);
      expect(validateNequiPhone('2001234567'), isNotNull);
      expect(validateNequiPhone('30012345'), isNotNull);
      expect(validateNequiPhone('abc'), isNotNull);
    });

    test('vacío es válido salvo que sea obligatorio', () {
      expect(validateNequiPhone(''), isNull);
      expect(validateNequiPhone(null), isNull);
      expect(validateNequiPhone('', required: true), isNotNull);
    });

    test('normalizeNequiPhone deja solo los 10 dígitos', () {
      expect(normalizeNequiPhone('+57 (300) 123-4567'), '3001234567');
      expect(normalizeNequiPhone('300 123 4567'), '3001234567');
    });

    test('formatNequiPhone lo muestra legible', () {
      expect(formatNequiPhone('3001234567'), '300 123 4567');
      expect(formatNequiPhone('123'), '123');
    });
  });

  group('PaymentRecord', () {
    test('newPendingMap arma el documento que aceptan las reglas', () {
      final map = PaymentRecord.newPendingMap(
        payerId: 'u1',
        amount: 25000,
        category: PaymentCategory.appointment,
        relatedId: 'a1',
        reference: '  M1234567 ',
        description: 'Cita',
      );
      expect(map['status'], 'pending');
      expect(map['method'], 'nequi');
      expect(map['reference'], 'M1234567');
      expect(map['resolvedAt'], isNull);
      expect(map['refundedAmount'], isNull);
      expect(map.keys.toSet(), {
        'payerId',
        'amount',
        'category',
        'relatedId',
        'description',
        'status',
        'createdAt',
        'resolvedAt',
        'refundedAmount',
        'reference',
        'method',
      });
    });

    test('fromMap lee referencia, quién resolvió y medio de reembolso', () {
      final record = PaymentRecord.fromMap('p1', {
        'payerId': 'u1',
        'amount': 20000,
        'category': 'product',
        'relatedId': 'x',
        'status': 'refunded',
        'reference': 'M1234567',
        'resolvedBy': 'staff1',
        'refundMethod': 'cash',
        'refundedAmount': 20000,
      });
      expect(record.reference, 'M1234567');
      expect(record.resolvedBy, 'staff1');
      expect(record.refundMethod, RefundMethod.cash);
      expect(record.isPending, isFalse);
    });
  });

  group('Purchase.isExpired', () {
    Purchase purchase(PurchaseStatus status, DateTime? expiresAt) => Purchase(
      id: 'p',
      barbershopId: 's',
      buyerId: 'b',
      items: const [],
      totalAmount: 1,
      status: status,
      expiresAt: expiresAt,
    );

    test(
      'lista para reclamar con el plazo vencido se muestra como vencida',
      () {
        final p = purchase(
          PurchaseStatus.pendingClaim,
          DateTime.now().subtract(const Duration(minutes: 1)),
        );
        expect(p.isExpired, isTrue);
        expect(p.displayStatus, PurchaseStatus.expired);
      },
    );

    test('vigente, reclamada o sin pagar no están vencidas', () {
      final future = DateTime.now().add(const Duration(hours: 3));
      expect(purchase(PurchaseStatus.pendingClaim, future).isExpired, isFalse);
      expect(
        purchase(
          PurchaseStatus.claimed,
          DateTime.now().subtract(const Duration(days: 2)),
        ).isExpired,
        isFalse,
      );
      expect(purchase(PurchaseStatus.pendingPayment, null).isExpired, isFalse);
    });

    test('itemsLabel resume lo comprado', () {
      final p = Purchase.fromMap('p', {
        'items': [
          {'productName': 'Cera', 'quantity': 2, 'unitPrice': 10},
          {'productName': 'Aceite', 'quantity': 1, 'unitPrice': 20},
        ],
        'status': 'pending_payment',
        'createdAt': Timestamp.now(),
      });
      expect(p.itemsLabel, 'Cera ×2, Aceite ×1');
    });
  });

  group('Barbershop.isOperational (mismo criterio que las reglas)', () {
    final now = DateTime(2026, 10, 10);
    Barbershop shop({DateTime? due, bool active = true}) => Barbershop(
      id: 's',
      ownerId: 'o',
      name: 'S',
      active: active,
      approvalStatus: BarbershopApprovalStatus.approved,
      paymentDueDate: due,
    );

    test('sin vencimiento o vigente opera', () {
      expect(shop().isOperational(graceDays: 4, now: now), isTrue);
      expect(
        shop(due: now.add(const Duration(days: 5)))
            .isOperational(graceDays: 4, now: now),
        isTrue,
      );
    });

    test('vencida dentro de la gracia opera; pasada la gracia no', () {
      expect(
        shop(due: now.subtract(const Duration(days: 3)))
            .isOperational(graceDays: 4, now: now),
        isTrue,
      );
      expect(
        shop(due: now.subtract(const Duration(days: 5)))
            .isOperational(graceDays: 4, now: now),
        isFalse,
      );
      expect(
        shop(due: now.subtract(const Duration(days: 5)))
            .isOperational(graceDays: 10, now: now),
        isTrue,
      );
    });

    test('inactiva o sin aprobar nunca opera', () {
      expect(
        shop(active: false).isOperational(graceDays: 4, now: now),
        isFalse,
      );
      const pending = Barbershop(
        id: 's',
        ownerId: 'o',
        name: 'S',
        active: true,
      );
      expect(pending.isOperational(graceDays: 4, now: now), isFalse);
    });
  });
}
