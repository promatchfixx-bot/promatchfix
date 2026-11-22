class TechnicianModel {
  final String userId;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? province;
  final String? district;
  final double? latitude;
  final double? longitude;
  final double inspectionFee;
  final double travelFeePerKm;
  final bool isOnline;
  final bool isApproved;
  final String? accountStatus;

  const TechnicianModel({
    required this.userId,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.province,
    this.district,
    this.latitude,
    this.longitude,
    this.inspectionFee = 0,
    this.travelFeePerKm = 0,
    this.isOnline = false,
    this.isApproved = false,
    this.accountStatus,
  });

  factory TechnicianModel.fromMaps({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> technician,
  }) {
    return TechnicianModel(
      userId: profile['id'].toString(),
      fullName: profile['full_name'] as String?,
      phone: profile['phone'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      province: technician['province'] as String?,
      district: technician['district'] as String?,
      latitude: _toDouble(technician['latitude']),
      longitude: _toDouble(technician['longitude']),
      inspectionFee: _toDouble(technician['inspection_fee']) ?? 0,
      travelFeePerKm: _toDouble(technician['travel_fee_per_km']) ?? 0,
      isOnline: technician['is_online'] == true,
      isApproved: technician['is_approved'] == true,
      accountStatus: profile['account_status'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool get isActive => accountStatus == 'active';

  Map<String, dynamic> toTechnicianMap() {
    return {
      'province': province,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'inspection_fee': inspectionFee,
      'travel_fee_per_km': travelFeePerKm,
    };
  }
}
