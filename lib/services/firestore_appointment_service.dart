import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../repositories/appointment_repository.dart';

class FirestoreAppointmentService implements AppointmentRepository {
  final FirebaseFirestore _firestore;

  FirestoreAppointmentService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appointments => _firestore.collection('appointments');

  @override
  Future<String> create(Appointment appointment) async {
    final doc = await _appointments.add(appointment.toMap());
    return doc.id;
  }

  @override
  Stream<List<Appointment>> watchByClient(String clientId) {
    return _appointments.where('clientId', isEqualTo: clientId).orderBy('date').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<Appointment>> watchByBarber(String barberId) {
    return _appointments.where('barberId', isEqualTo: barberId).orderBy('date').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Stream<List<Appointment>> watchByBarbershop(String barbershopId) {
    return _appointments.where('barbershopId', isEqualTo: barbershopId).orderBy('date').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Appointment.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> setStatus(String id, AppointmentStatus status) {
    return _appointments.doc(id).update({'status': status.value});
  }

  @override
  Future<void> reschedule(String id, DateTime newDate) {
    return _appointments.doc(id).update({'date': Timestamp.fromDate(newDate), 'status': AppointmentStatus.postponed.value});
  }
}
