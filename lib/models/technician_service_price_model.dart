class TechnicianServicePrice {
  final String id;
  final String technicianId;
  final String nameTh;
  final String? nameEn;
  final String? descriptionTh;
  final String? descriptionEn;
  final String priceType;
  final double minPrice;
  final double? maxPrice;
  final bool isActive;

  const TechnicianServicePrice({
    required this.id,
    required this.technicianId,
    required this.nameTh,
    this.nameEn,
    this.descriptionTh,
    this.descriptionEn,
    required this.priceType,
    required this.minPrice,
    this.maxPrice,
    required this.isActive,
  });

  factory TechnicianServicePrice.fromMap(Map<String, dynamic> map) {
    return TechnicianServicePrice(
      id: map['id'].toString(),
      technicianId: map['technician_id'].toString(),
      nameTh: map['service_name_th'] ?? '',
      nameEn: map['service_name_en'],
      descriptionTh: map['description_th'],
      descriptionEn: map['description_en'],
      priceType: map['price_type'] ?? 'fixed',
      minPrice: (map['min_price'] as num).toDouble(),
      maxPrice: map['max_price'] == null
          ? null
          : (map['max_price'] as num).toDouble(),
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'technician_id': technicianId,
      'service_name_th': nameTh,
      'service_name_en': nameEn,
      'description_th': descriptionTh,
      'description_en': descriptionEn,
      'price_type': priceType,
      'min_price': minPrice,
      'max_price': maxPrice,
      'is_active': isActive,
    };
  }
}
