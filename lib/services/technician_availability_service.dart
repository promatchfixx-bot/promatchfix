import 'package:supabase_flutter/supabase_flutter.dart';

class TechnicianAvailabilityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> canGoOnline() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อน');
    }

    final userId = user.id;

    // 1. ตรวจสอบบัญชี
    final profile = await _supabase
        .from('profiles')
        .select('role, account_status')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null ||
        profile['role'] != 'technician' ||
        profile['account_status'] != 'active') {
      return false;
    }

    // 2. ตรวจสอบการอนุมัติช่าง
    final technician = await _supabase
        .from('technician_profiles')
        .select('is_approved')
        .eq('user_id', userId)
        .maybeSingle();

    if (technician == null || technician['is_approved'] != true) {
      return false;
    }

    // 3. ตรวจสอบสมาชิก
    final subscription = await _supabase
        .from('subscriptions')
        .select('status, expires_at')
        .eq('technician_id', userId)
        .eq('status', 'active')
        .order('expires_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (subscription == null) {
      return false;
    }

    final expiresAt = DateTime.tryParse(
      subscription['expires_at']?.toString() ?? '',
    );

    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    return true;
  }

  Future<void> setOnline(bool online) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('ไม่พบผู้ใช้งาน');
    }

    if (online) {
      final allowed = await canGoOnline();

      if (!allowed) {
        throw Exception(
          'ไม่สามารถออนไลน์ได้ กรุณาตรวจสอบ KYC '
          'การอนุมัติบัญชี และสมาชิกของคุณ',
        );
      }
    }

    await _supabase
        .from('technician_profiles')
        .update({'is_online': online})
        .eq('user_id', user.id);
  }

  Future<bool> getOnlineStatus() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return false;

    final result = await _supabase
        .from('technician_profiles')
        .select('is_online')
        .eq('user_id', user.id)
        .maybeSingle();

    return result?['is_online'] == true;
  }
}
