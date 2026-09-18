class Service {
  final String id;
  final String barbershopId;
  final String name;
  final String? description;
  final double price;
  final int durationMinutes;
  final String? photoUrl;
  final bool active;

  const Service({
    required this.id,
    required this.barbershopId,
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.description,
    this.photoUrl,
    this.active = true,
  });

  factory Service.fromMap(String id, String barbershopId, Map<String, dynamic> map) {
    return Service(
      id: id,
      barbershopId: barbershopId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      photoUrl: map['photoUrl'] as String?,
      active: map['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
      'photoUrl': photoUrl,
      'active': active,
    };
  }
}
