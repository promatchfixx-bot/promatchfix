class TechnicianLocation {
  final String technicianId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime updatedAt;

  const TechnicianLocation({
    required this.technicianId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
  });

  factory TechnicianLocation.fromJson(Map<String, dynamic> json) {
    return TechnicianLocation(
      technicianId: json['technician_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy_m'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  bool get isFresh => DateTime.now().difference(updatedAt).inSeconds <= 120;
}
