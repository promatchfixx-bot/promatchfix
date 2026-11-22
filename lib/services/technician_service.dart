import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/technician_model.dart';

class TechnicianService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    return user.id;
  }

  Future<TechnicianModel> getMyProfile() async {
    final userId = _userId;

    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    if (profile['role'] != 'technician') {
      throw Exception('บัญชีนี้ไม่ใช่บัญชีช่าง');
    }

    final technician = await _client
        .from('technician_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (technician == null) {
      throw Exception('ไม่พบข้อมูลโปรไฟล์ช่าง');
    }

    return TechnicianModel.fromMaps(profile: profile, technician: technician);
  }

  Future<void> updateMyProfile({
    required String fullName,
    required String phone,
    required String province,
    required String district,
    required double inspectionFee,
    required double travelFeePerKm,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _userId;

    if (fullName.trim().isEmpty) {
      throw Exception('กรุณากรอกชื่อ-นามสกุล');
    }

    if (province.trim().isEmpty || district.trim().isEmpty) {
      throw Exception('กรุณากรอกจังหวัดและอำเภอ');
    }

    if (inspectionFee < 0 || travelFeePerKm < 0) {
      throw Exception('ค่าบริการต้องไม่ติดลบ');
    }

    if ((latitude == null) != (longitude == null)) {
      throw Exception('กรุณาระบุพิกัดให้ครบทั้งสองค่า');
    }

    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw Exception('Latitude ไม่ถูกต้อง');
    }

    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw Exception('Longitude ไม่ถูกต้อง');
    }

    await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'phone': phone.trim().isEmpty ? null : phone.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    await _client
        .from('technician_profiles')
        .update({
          'province': province.trim(),
          'district': district.trim(),
          'inspection_fee': inspectionFee,
          'travel_fee_per_km': travelFeePerKm,
          'latitude': latitude,
          'longitude': longitude,
        })
        .eq('user_id', userId);
  }
}
