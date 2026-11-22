import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/technician_service_price_model.dart';

class TechnicianPricingService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'technician_service_prices';

  String get _userId {
    final id = _client.auth.currentUser?.id;

    if (id == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    return id;
  }

  Future<List<TechnicianServicePrice>> getMyPrices() async {
    final result = await _client
        .from(_table)
        .select()
        .eq('technician_id', _userId)
        .order('created_at');

    return result
        .map<TechnicianServicePrice>(
          (item) => TechnicianServicePrice.fromMap(item),
        )
        .toList();
  }

  Future<void> addPrice({
    required String nameTh,
    String? nameEn,
    String? descriptionTh,
    String? descriptionEn,
    required String priceType,
    required double minPrice,
    double? maxPrice,
  }) async {
    if (nameTh.trim().isEmpty) {
      throw Exception('กรุณากรอกชื่อบริการ');
    }

    if (minPrice < 0) {
      throw Exception('ราคาไม่ถูกต้อง');
    }

    if (maxPrice != null && maxPrice < minPrice) {
      throw Exception('ราคาสูงสุดต้องไม่น้อยกว่าราคาต่ำสุด');
    }

    await _client.from(_table).insert({
      'technician_id': _userId,
      'service_name_th': nameTh.trim(),
      'service_name_en': nameEn?.trim(),
      'description_th': descriptionTh?.trim(),
      'description_en': descriptionEn?.trim(),
      'price_type': priceType,
      'min_price': minPrice,
      'max_price': maxPrice,
    });
  }

  Future<void> updatePrice({
    required String id,
    required String nameTh,
    String? nameEn,
    String? descriptionTh,
    required String priceType,
    required double minPrice,
    double? maxPrice,
    required bool isActive,
  }) async {
    await _client
        .from(_table)
        .update({
          'service_name_th': nameTh.trim(),
          'service_name_en': nameEn?.trim(),
          'description_th': descriptionTh?.trim(),
          'price_type': priceType,
          'min_price': minPrice,
          'max_price': maxPrice,
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .eq('technician_id', _userId);
  }

  Future<void> deletePrice(String id) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('technician_id', _userId);
  }
}
