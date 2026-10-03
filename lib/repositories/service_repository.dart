import 'dart:typed_data';

import '../models/service.dart';

abstract class ServiceRepository {
  Stream<List<Service>> watchByBarbershop(String barbershopId);

  Future<void> create(Service service);

  /// Guarda los cambios de un servicio existente (nombre, precio, duración,
  /// foto…). Las citas ya creadas conservan el precio con el que se reservaron.
  Future<void> update(Service service);

  /// Elimina el servicio del catálogo. Las citas ya creadas no se afectan
  /// (guardan su propia copia del nombre y precio).
  Future<void> delete(String barbershopId, String serviceId);

  Future<void> setActive(String barbershopId, String serviceId, bool active);

  /// Sube la foto del servicio (tomada con cámara o elegida de galería) y
  /// devuelve la URL pública.
  Future<String> uploadPhoto({
    required String barbershopId,
    required String fileName,
    required Uint8List bytes,
  });
}
