import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/shop_closure.dart';
import '../repositories/shop_closure_repository.dart';
import '../utils/date_labels.dart';
import 'appointment_slot_id.dart';

const _openAppointmentStatuses = {'pending', 'accepted', 'postponed'};
const _openPurchaseStatuses = {'pending_payment', 'pending_claim'};

// Nombre histórico (antes llamaba a closeShopForExternalEvent, Cloud
// Function) — sin plan Blaze escribe Firestore directo.
//
// Qué hace un cierre:
//  - Cita PAGADA dentro del cierre: queda aplazada (el cliente la
//    reprograma), conserva su pago y lleva el descuento obligatorio de
//    calificación (spec 3.4).
//  - Cita SIN pago dentro del cierre: se cancela, sin penalización.
//  - Compra de productos sin entregar: se mantiene y el comprador recibe
//    el aviso.
//  - Cada cliente afectado recibe una notificación dentro de la app. Sin
//    servidor no hay push con la app cerrada (ver cloud_barber_
//    availability_service.dart); el aviso lo ve al abrirla.
//  - La barbería queda marcada con `closure`: el catálogo la muestra como
//    cerrada y las reglas rechazan reservas dentro del cierre.
class CloudShopClosureService implements ShopClosureRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudShopClosureService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Avisos que se escriben a la vez.
  static const _notificationChunk = 20;

  DocumentReference<Map<String, dynamic>> _shop(String id) =>
      _firestore.collection('barbershops').doc(id);

  /// Citas abiertas de la barbería que caen dentro del cierre.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _appointments(
    String barbershopId,
    DateTime from,
    DateTime? until,
  ) async {
    var query = _firestore
        .collection('appointments')
        .where('barbershopId', isEqualTo: barbershopId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (until != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(until),
      );
    }
    final snap = await query.get();
    return [
      for (final doc in snap.docs)
        if (_openAppointmentStatuses.contains(doc.data()['status'])) doc,
    ];
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _purchases(
    String barbershopId,
  ) async {
    final snap = await _firestore
        .collection('purchases')
        .where('barbershopId', isEqualTo: barbershopId)
        .get();
    return [
      for (final doc in snap.docs)
        if (_openPurchaseStatuses.contains(doc.data()['status'])) doc,
    ];
  }

  @override
  Future<ClosureImpact> previewImpact({
    required String barbershopId,
    required DateTime closedFrom,
    DateTime? closedUntil,
  }) async {
    final appointments = await _appointments(
      barbershopId,
      closedFrom,
      closedUntil,
    );
    final paid = appointments.where((d) => d.data()['paid'] == true).length;
    final purchases = await _purchases(barbershopId);
    return ClosureImpact(
      paidAppointments: paid,
      unpaidAppointments: appointments.length - paid,
      purchases: purchases.length,
    );
  }

  @override
  Future<ClosureResult> closeForExternalEvent({
    required String barbershopId,
    required DateTime closedFrom,
    DateTime? closedUntil,
    required String reason,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Debes indicar el motivo del cierre.');
    }
    if (closedUntil != null && !closedUntil.isAfter(closedFrom)) {
      throw Exception('El final del cierre debe ser posterior al inicio.');
    }

    final shopSnap = await _shop(barbershopId).get();
    final shopName = (shopSnap.data()?['name'] as String?) ?? 'La barbería';

    final closureRef = _firestore.collection('shopClosures').doc();
    await closureRef.set({
      'barbershopId': barbershopId,
      'closedFrom': Timestamp.fromDate(closedFrom),
      'closedUntil': closedUntil == null
          ? null
          : Timestamp.fromDate(closedUntil),
      'reason': trimmedReason,
      'requestedBy': uid,
      'appointmentsAffected': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final closure = ShopClosure(
      id: closureRef.id,
      from: closedFrom,
      until: closedUntil,
      reason: trimmedReason,
    );
    // Primero se marca la barbería: desde este momento nadie nuevo reserva
    // dentro del cierre mientras se procesan las reservas que ya existían.
    await _shop(barbershopId).update({'closure': closure.toMap()});

    final whenText = closure.untilLabel(dateTimeLabel);
    final notices = <_Notice>[];
    var postponed = 0;
    var cancelled = 0;

    final appointments = await _appointments(
      barbershopId,
      closedFrom,
      closedUntil,
    );
    for (final doc in appointments) {
      final data = doc.data();
      final date = (data['date'] as Timestamp).toDate();
      final clientId = data['clientId'] as String?;
      final service = data['serviceName'] as String? ?? 'tu servicio';
      final isPaid = data['paid'] == true;

      if (isPaid) {
        final slotRef = _firestore
            .collection('appointmentSlots')
            .doc(appointmentSlotId(data['barberId'] as String, date));
        await Future.wait([
          doc.reference.update({
            'status': 'postponed',
            'forcedRatingPenalty': true,
          }),
          slotRef.delete(),
        ]);
        postponed++;
      } else {
        await doc.reference.update({'status': 'cancelled'});
        cancelled++;
      }
      if (clientId != null && clientId.isNotEmpty) {
        notices.add(
          _Notice(
            relatedId: doc.id,
            kind: 'appointment',
            toUserId: clientId,
            title: isPaid
                ? '$shopName cerró: tu cita quedó aplazada'
                : '$shopName cerró: tu cita fue cancelada',
            body: isPaid
                ? 'Tu cita de $service del ${dateTimeLabel(date)} quedó '
                      'aplazada porque la barbería está cerrada '
                      '$whenText ($trimmedReason). Tu pago sigue en pie: '
                      'reprograma cuando quieras desde "Mis citas".'
                : 'Tu cita de $service del ${dateTimeLabel(date)} se '
                      'canceló porque la barbería está cerrada $whenText '
                      '($trimmedReason). Puedes reservar otra cuando vuelva '
                      'a abrir.',
          ),
        );
      }
    }

    final purchases = await _purchases(barbershopId);
    for (final doc in purchases) {
      final data = doc.data();
      final buyerId = data['buyerId'] as String?;
      if (buyerId == null || buyerId.isEmpty) continue;
      final waitingPayment = data['status'] == 'pending_payment';
      notices.add(
        _Notice(
          relatedId: doc.id,
          kind: 'purchase',
          toUserId: buyerId,
          title: '$shopName cerró: tu compra sigue pendiente',
          body: waitingPayment
              ? 'Tu compra de productos espera que la barbería verifique el '
                    'pago, pero está cerrada $whenText ($trimmedReason). '
                    'Se atenderá cuando vuelva a abrir.'
              : 'Tu compra de productos está lista para reclamar, pero la '
                    'barbería está cerrada $whenText ($trimmedReason). '
                    'Escríbele para acordar la entrega: el plazo de 24 h '
                    'puede vencer antes.',
        ),
      );
    }

    final sent = await _notify(
      closureId: closureRef.id,
      barbershopId: barbershopId,
      notices: notices,
    );

    await closureRef.update({
      'appointmentsAffected': postponed + cancelled,
      'notificationsSent': sent,
    });

    return ClosureResult(
      postponed: postponed,
      cancelled: cancelled,
      purchasesNotified: purchases.length,
      notificationsSent: sent,
      notificationsFailed: notices.length - sent,
    );
  }

  /// Guarda un aviso por cliente afectado. El id es determinista
  /// (`closure_{cierre}_{cita o compra}`): las reglas lo exigen para que el
  /// dueño solo pueda avisar a quien de verdad tiene algo con su barbería, y
  /// reintentar nunca duplica avisos. Devuelve cuántos quedaron guardados.
  Future<int> _notify({
    required String closureId,
    required String barbershopId,
    required List<_Notice> notices,
  }) async {
    var sent = 0;
    for (var i = 0; i < notices.length; i += _notificationChunk) {
      final chunk = notices.skip(i).take(_notificationChunk);
      final results = await Future.wait(
        chunk.map((notice) async {
          try {
            await _firestore
                .collection('notifications')
                .doc('closure_${closureId}_${notice.relatedId}')
                .set({
                  'toUserId': notice.toUserId,
                  'title': notice.title,
                  'body': notice.body,
                  'type': 'shop_closure',
                  'read': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'barbershopId': barbershopId,
                  'closureId': closureId,
                  'relatedKind': notice.kind,
                  'relatedId': notice.relatedId,
                });
            return true;
          } catch (error) {
            debugPrint('Aviso de cierre no enviado: $error');
            return false;
          }
        }),
      );
      sent += results.where((ok) => ok).length;
    }
    return sent;
  }

  @override
  Future<void> reopen(String barbershopId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Debes iniciar sesión.');
    final snap = await _shop(barbershopId).get();
    final closure = ShopClosure.fromMap(snap.data()?['closure']);
    await _shop(barbershopId).update({'closure': FieldValue.delete()});
    if (closure != null && closure.id.isNotEmpty) {
      try {
        await _firestore.collection('shopClosures').doc(closure.id).update({
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        debugPrint('No se pudo cerrar el registro del cierre: $error');
      }
    }
  }
}

class _Notice {
  final String relatedId;
  final String kind;
  final String toUserId;
  final String title;
  final String body;

  const _Notice({
    required this.relatedId,
    required this.kind,
    required this.toUserId,
    required this.title,
    required this.body,
  });
}
