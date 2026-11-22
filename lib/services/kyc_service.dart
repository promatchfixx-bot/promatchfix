import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class KycService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> submitKyc({
    required String nationalId,
    required Uint8List imageBytes,
    required String fileExtension,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null || profile['role'] != 'technician') {
      throw Exception('อนุญาตเฉพาะบัญชีช่างเท่านั้น');
    }

    if (!_isValidThaiNationalId(nationalId)) {
      throw Exception('เลขบัตรประชาชนไม่ถูกต้อง');
    }

    final existing = await _client
        .from('technician_kyc')
        .select('id, status')
        .eq('technician_id', user.id)
        .inFilter('status', ['pending', 'approved']);

    if ((existing as List).isNotEmpty) {
      throw Exception('คุณมีรายการ KYC ที่กำลังตรวจสอบหรือผ่านแล้ว');
    }

    if (imageBytes.isEmpty) {
      throw Exception('ไม่พบรูปบัตรประชาชน');
    }

    if (imageBytes.length > 5 * 1024 * 1024) {
      throw Exception('รูปภาพต้องมีขนาดไม่เกิน 5 MB');
    }

    final extension = fileExtension.toLowerCase();

    final contentTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };

    final contentType = contentTypes[extension];

    if (contentType == null) {
      throw Exception('รองรับเฉพาะ JPG, PNG และ WebP');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final filePath = '${user.id}/kyc_$timestamp.$extension';

    await _client.storage
        .from('technician-kyc')
        .uploadBinary(
          filePath,
          imageBytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    try {
      await _client.from('technician_kyc').insert({
        'technician_id': user.id,
        'status': 'pending',
        'national_id_last4': nationalId.substring(9),
        'card_image_path': filePath,
      });
    } catch (_) {
      await _client.storage.from('technician-kyc').remove([filePath]);

      rethrow;
    }
  }

  bool _isValidThaiNationalId(String value) {
    if (!RegExp(r'^[0-9]{13}$').hasMatch(value)) {
      return false;
    }

    int sum = 0;

    for (int i = 0; i < 12; i++) {
      sum += int.parse(value[i]) * (13 - i);
    }

    final checkDigit = (11 - (sum % 11)) % 10;

    return checkDigit == int.parse(value[12]);
  }

  Future<Map<String, dynamic>?> getMyKycStatus() async {
    final user = _client.auth.currentUser;

    if (user == null) return null;

    final result = await _client
        .from('technician_kyc')
        .select('id, status, rejection_reason, submitted_at, reviewed_at')
        .eq('technician_id', user.id)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return result;
  }
}
