import 'dart:typed_data';

import '../models/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> watchByBarbershop(String barbershopId);

  Future<void> create(Product product);

  Future<void> setActive(String barbershopId, String productId, bool active);

  Future<String> uploadPhoto({required String barbershopId, required String fileName, required Uint8List bytes});
}
