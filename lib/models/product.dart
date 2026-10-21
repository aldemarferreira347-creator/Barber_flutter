class Product {
  final String id;
  final String barbershopId;
  final String name;
  final String? description;
  final double price;
  final String? photoUrl;
  final bool active;

  /// Unidades disponibles en la barbería. `null` = la barbería no lleva
  /// control de inventario de este producto (se puede vender sin límite);
  /// un número, incluido 0, = inventario controlado.
  final int? stock;

  /// Con stock controlado igual o menor a este número se avisa "quedan pocas".
  static const lowStockThreshold = 3;

  const Product({
    required this.id,
    required this.barbershopId,
    required this.name,
    required this.price,
    this.description,
    this.photoUrl,
    this.active = true,
    this.stock,
  });

  bool get tracksStock => stock != null;

  /// Se puede comprar al menos una unidad.
  bool get inStock => stock == null || stock! > 0;

  bool get isLowStock =>
      stock != null && stock! > 0 && stock! <= lowStockThreshold;

  /// Máximo que se puede pedir de una vez.
  int maxPurchasable(int cap) => stock == null ? cap : stock!.clamp(0, cap);

  factory Product.fromMap(
    String id,
    String barbershopId,
    Map<String, dynamic> map,
  ) {
    return Product(
      id: id,
      barbershopId: barbershopId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      photoUrl: map['photoUrl'] as String?,
      active: map['active'] as bool? ?? true,
      stock: (map['stock'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'photoUrl': photoUrl,
      'active': active,
      'stock': stock,
    };
  }
}
