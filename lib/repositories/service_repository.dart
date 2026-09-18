import 'dart:typed_data';

import '../models/service.dart';

abstract class ServiceRepository {
  Stream<List<Service>> watchByBarbershop(String barbershopId);

  Future<void> create(Service service);

  Future<void> setActive(String barbershopId, String serviceId, bool active);

  /// Sube la foto del servicio (tomada con cámara o elegida de galería) y
  /// devuelve la URL pública. [bytes] funciona igual en web y móvil (a
  /// diferencia de un File de dart:io, que no existe en web).
  Future<String> uploadPhoto({
    required String barbershopId,
    required String fileName,
    required Uint8List bytes,
  });
}
