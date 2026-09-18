import '../models/app_user.dart';
import '../models/user_role.dart';

/// Abstracción sobre la persistencia de perfiles de usuario (users/{uid}).
abstract class UserRepository {
  Future<void> createUserProfile(AppUser user);

  Future<AppUser?> fetchUserProfile(String uid);

  Stream<AppUser?> watchUserProfile(String uid);

  Stream<List<AppUser>> watchAll();

  /// Bloqueo/desbloqueo selectivo — reservado al rol admin (impuesto también
  /// en firestore.rules, no solo en el cliente).
  Future<void> setActive(String uid, bool active);

  /// Cambiar el rol de un usuario (p.ej. ascender un Cliente a Dueño tras
  /// pago, o a Barbero) — reservado al rol admin (impuesto también en
  /// firestore.rules).
  Future<void> setRole(String uid, UserRole role);

  /// Barberos activos de una barbería (role == barber && barbershopId == id).
  Stream<List<AppUser>> watchBarbersByBarbershop(String barbershopId);

  /// Busca un usuario por correo exacto (para que el Dueño encuentre un
  /// Cliente existente y lo contrate como Barbero). Null si no existe.
  Future<AppUser?> findByEmail(String email);

  /// El Dueño contrata a un Cliente existente como Barbero de su barbería
  /// (reservado a: el propio Dueño de esa barbería, impuesto en firestore.rules).
  Future<void> hireAsBarber({required String uid, required String barbershopId});

  /// El Dueño da de baja a un Barbero de su barbería: vuelve a Cliente.
  Future<void> releaseFromBarbershop(String uid);

  /// El propio Barbero marca si está disponible para recibir citas nuevas.
  Future<void> setAvailable(String uid, bool available);
}
