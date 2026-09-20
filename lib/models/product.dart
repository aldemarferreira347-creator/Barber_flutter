class Product {
  final String id;
  final String barbershopId;
  final String name;
  final String? description;
  final double price;
  final String? photoUrl;
  final bool active;

  const Product({
    required this.id,
    required this.barbershopId,
    required this.name,
    required this.price,
    this.description,
    this.photoUrl,
    this.active = true,
  });

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'photoUrl': photoUrl,
      'active': active,
    };
  }
}
