import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';

class FirestoreAppointmentService implements AppointmentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirestoreAppointmentService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _appointments => _firestore.collection('appointments');

  @override
  Future<String> create(Appointment appointment) async {
    final doc = await _appointments.add(appointment.toMap());
    return doc.id;
  }

  @override
  Future<String> createPaid({
    required String barbershopId,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String clientName,
    required DateTime date,
  }) async {
    final result = await _functions.httpsCallable('bookPaidAppointment').call<Map<String, dynamic>>({
      'barbershopId': barbershopId,
      'barberId': barberId,
      'barberName': barberName,
      'serviceId': serviceId,
      'clientName': clientName,
      'date': date.toIso8601String(),
    });
    return result.data['id'] as String;
  }

  @override
  Stream<List<Appointment>> watchByClient(String clientId) {
    return _appointments
        .where('clientId', isEqualTo: clientId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<Appointment>> watchByBarber(String barberId) {
    return _appointments
        .where('barberId', isEqualTo: barberId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<Appointment>> watchByBarbershop(String barbershopId) {
    return _appointments
        .where('barbershopId', isEqualTo: barbershopId)
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<void> setStatus(String id, AppointmentStatus status) {
    return _appointments.doc(id).update({'status': status.value});
  }

  @override
  Future<void> reschedule(String id, DateTime newDate) {
    return _appointments.doc(id).update({
      'date': Timestamp.fromDate(newDate),
      'status': AppointmentStatus.postponed.value,
    });
  }

  @override
  Future<void> postponePaid(String appointmentId, DateTime newDate) {
    return _functions.httpsCallable('postponeAppointment').call<void>({
      'appointmentId': appointmentId,
      'newDate': newDate.toIso8601String(),
    });
  }

  @override
  Future<String> requestRefund({
    required String appointmentId,
    required String reason,
    String? purchaseId,
    List<int>? purchaseItemIndexes,
  }) async {
    final result = await _functions.httpsCallable('requestAppointmentRefund').call<Map<String, dynamic>>({
      'appointmentId': appointmentId,
      'reason': reason,
      'purchaseId': purchaseId,
      'purchaseItemIndexes': purchaseItemIndexes,
    });
    return result.data['id'] as String;
  }
}
