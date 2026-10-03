import 'dart:typed_data';

import '../models/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchByBarbershop(String barbershopId);

  Future<void> create(Product product);

  /// Guarda los cambios de un producto existente. Las compras ya hechas
  /// conservan el precio con el que se pagaron.
  Future<void> update(Product product);

  /// Elimina el producto del catálogo. Las compras ya hechas no se afectan.
  Future<void> delete(String barbershopId, String productId);

  Future<void> setActive(String barbershopId, String productId, bool active);

  Future<String> uploadPhoto({
    required String barbershopId,
    required String fileName,
    required Uint8List bytes,
  });
}
