import 'dart:typed_data';

/// Único punto de subida/borrado de archivos de toda la app. Cada feature
/// decide su propio prefijo de ruta (p.ej. `barbershops/$id/services/...`)
/// pero ninguna depende de Firebase Storage directamente (Dependency
/// Inversion) — así se puede sustituir en tests y no se duplica la
/// integración con el SDK de Storage en cada repositorio de feature.
abstract class StorageRepository {
  /// Sube [bytes] a [path] y devuelve la URL pública de descarga. [bytes]
  /// funciona igual en web y móvil (a diferencia de un File de dart:io,
  /// que no existe en web).
  Future<String> uploadBytes({required String path, required Uint8List bytes});

  Future<void> delete(String path);
}
