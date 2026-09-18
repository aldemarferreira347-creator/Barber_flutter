import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import '../repositories/user_repository.dart';

/// CRUD del documento de perfil/rol en users/{uid}.
class FirestoreUserService implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _firestore.collection('users');

  @override
  Future<void> createUserProfile(AppUser user) {
    return _users.doc(user.uid).set(user.toMap());
  }

  @override
  Future<AppUser?> fetchUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return AppUser.fromMap(uid, data);
  }

  @override
  Stream<AppUser?> watchUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AppUser.fromMap(uid, data);
    });
  }

  @override
  Stream<List<AppUser>> watchAll() {
    return _users.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList(),
        );
  }

  @override
  Future<void> setActive(String uid, bool active) {
    return _users.doc(uid).update({'active': active});
  }

  @override
  Future<void> setRole(String uid, UserRole role) {
    return _users.doc(uid).update({'role': role.value});
  }

  @override
  Stream<List<AppUser>> watchBarbersByBarbershop(String barbershopId) {
    return _users
        .where('barbershopId', isEqualTo: barbershopId)
        .where('role', isEqualTo: UserRole.barber.value)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<AppUser?> findByEmail(String email) async {
    // El filtro por role=='client' va también en la consulta (no solo en
    // firestore.rules): Firestore valida las reglas de una consulta contra
    // su forma ANTES de ejecutarla, y como el resto de las reglas de
    // lectura dependen de campos que esta consulta no fija (barbershopId,
    // uid propio), rechaza la consulta entera si no incluye aquí el mismo
    // filtro que la hace demostrablemente segura.
    final snapshot = await _users
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('role', isEqualTo: UserRole.client.value)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AppUser.fromMap(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  @override
  Future<void> hireAsBarber({required String uid, required String barbershopId}) {
    return _users.doc(uid).update({'role': UserRole.barber.value, 'barbershopId': barbershopId});
  }

  @override
  Future<void> releaseFromBarbershop(String uid) {
    return _users.doc(uid).update({'role': UserRole.client.value, 'barbershopId': null});
  }

  @override
  Future<void> setAvailable(String uid, bool available) {
    return _users.doc(uid).update({'available': available});
  }
}
