import 'package:supabase_flutter/supabase_flutter.dart';

import 'kyc_service.dart';
import 'technician_service.dart';

class JobBoardService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('กรุณาเข้าสู่ระบบก่อนใช้งาน');
    return id;
  }

  getCategories() async {
    final result = await _client
        .from('service_categories')
        .select('id, name_th, name_en, slug')
        .eq('is_active', true)
        .order('id');

    return List.from(result);
  }

  getMyTechnicianDefaults() async {
    try {
      final tech = await TechnicianService().getMyProfile();
      final name = tech.fullName?.trim() ?? '';
      final phone = tech.phone?.trim() ?? '';
      if (name.isNotEmpty || phone.isNotEmpty) {
        return {'name': name, 'phone': phone};
      }
    } catch (_) {}

    try {
      final profile = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', _userId)
          .maybeSingle();
      return {
        'name': profile?['full_name']?.toString().trim() ?? '',
        'phone': profile?['phone']?.toString().trim() ?? '',
      };
    } catch (_) {
      return {'name': '', 'phone': ''};
    }
  }

  bool _isPositiveKycValue(dynamic val) {
    if (val == null) return false;
    if (val == true || val == 1) return true;
    final s = val.toString().trim().toLowerCase();
    return s == 'approved' ||
        s == 'verified' ||
        s == 'confirmed' ||
        s == 'completed' ||
        s == 'passed' ||
        s == 'true' ||
        s == '1' ||
        s.contains('ยืนยันตัวตนสำเร็จ') ||
        s.contains('ผ่านการยืนยัน');
  }

  isTechnicianKycVerified() async {
    try {
      final kycData = await KycService().getMyKycStatus();
      if (kycData != null) {
        for (final key in ['status', 'kyc_status', 'verification_status']) {
          if (_isPositiveKycValue(kycData[key])) {
            return true;
          }
        }
      }
    } catch (_) {}

    try {
      final profile = await _client
          .from('profiles')
          .select('*')
          .eq('id', _userId)
          .maybeSingle();

      if (profile != null) {
        for (final key in [
          'kyc_status',
          'verification_status',
          'id_verification_status',
          'kyc_state',
          'status',
        ]) {
          if (_isPositiveKycValue(profile[key])) {
            return true;
          }
        }
        for (final key in [
          'is_kyc_verified',
          'kyc_verified',
          'is_verified',
          'verified',
          'id_verified',
        ]) {
          if (_isPositiveKycValue(profile[key])) {
            return true;
          }
        }
      }
    } catch (_) {}

    for (final table in [
      'kyc_submissions',
      'kyc_verifications',
      'technician_kyc',
    ]) {
      try {
        final row = await _client
            .from(table)
            .select('*')
            .or(
              'user_id.eq.$_userId,technician_id.eq.$_userId,profile_id.eq.$_userId,id.eq.$_userId',
            )
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (row != null) {
          for (final key in ['status', 'kyc_status', 'verification_status']) {
            if (_isPositiveKycValue(row[key])) {
              return true;
            }
          }
          for (final key in [
            'is_verified',
            'verified',
            'is_approved',
            'approved',
          ]) {
            if (_isPositiveKycValue(row[key])) {
              return true;
            }
          }
        }
      } catch (_) {}
    }

    return false;
  }

  createJobPost({
    required String title,
    required String description,
    required int categoryId,
    required String province,
    required String district,
    double? budget,
    DateTime? preferredAt,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('กรุณาระบุหัวข้องาน');
    }

    if (description.trim().isEmpty) {
      throw Exception('กรุณาระบุรายละเอียดงาน');
    }

    await _client.from('job_posts').insert({
      'customer_id': _userId,
      'category_id': categoryId,
      'title': title.trim(),
      'description': description.trim(),
      'province': province.trim(),
      'district': district.trim(),
      'budget': budget,
      'preferred_at': preferredAt?.toUtc().toIso8601String(),
      'status': 'open',
    });
  }

  updateJobPost({
    required String jobPostId,
    required String title,
    required String description,
    required int categoryId,
    required String province,
    required String district,
    double? budget,
    DateTime? preferredAt,
  }) async {
    if (title.trim().isEmpty) {
      throw Exception('กรุณาระบุหัวข้องาน');
    }
    if (description.trim().isEmpty) {
      throw Exception('กรุณาระบุรายละเอียดงาน');
    }

    final updated = await _client
        .from('job_posts')
        .update({
          'title': title.trim(),
          'description': description.trim(),
          'category_id': categoryId,
          'province': province.trim(),
          'district': district.trim(),
          'budget': budget,
          'preferred_at': preferredAt?.toUtc().toIso8601String(),
        })
        .eq('id', jobPostId)
        .eq('customer_id', _userId)
        .select();

    if (List.from(updated).isEmpty) {
      throw Exception('ไม่สามารถแก้ไขประกาศงานนี้ได้');
    }
  }

  toggleJobPostStatus({
    required String jobPostId,
    required String nextStatus,
  }) async {
    if (nextStatus != 'open' && nextStatus != 'closed') {
      throw Exception('สถานะประกาศงานไม่ถูกต้อง');
    }

    final updated = await _client
        .from('job_posts')
        .update({'status': nextStatus})
        .eq('id', jobPostId)
        .eq('customer_id', _userId)
        .neq('status', 'assigned')
        .select();

    if (List.from(updated).isEmpty) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะประกาศงานนี้ได้');
    }
  }

  deleteJobPost(String jobPostId) async {
    final deleted = await _client
        .from('job_posts')
        .delete()
        .eq('id', jobPostId)
        .eq('customer_id', _userId)
        .select();

    if (List.from(deleted).isEmpty) {
      throw Exception('ไม่สามารถลบประกาศงานนี้ได้');
    }
  }

  getMyJobPosts() async {
    final result = await _client
        .from('job_posts')
        .select('*, service_categories(name_th, name_en)')
        .eq('customer_id', _userId)
        .order('created_at', ascending: false);

    return List.from(result);
  }

  getOpenJobPosts({
    int? categoryId,
    String? province,
    String? district,
  }) async {
    var query = _client
        .from('job_posts')
        .select('*, service_categories(name_th, name_en)')
        .eq('status', 'open');

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    if (province != null && province.trim().isNotEmpty) {
      query = query.ilike('province', '%${province.trim()}%');
    }

    if (district != null && district.trim().isNotEmpty) {
      query = query.ilike('district', '%${district.trim()}%');
    }

    final result = await query.order('created_at', ascending: false);

    return List.from(result);
  }

  submitQuotation({
    required String jobPostId,
    required String technicianName,
    required double price,
    required String phone,
    String? terms,
  }) async {
    final verified = await isTechnicianKycVerified();
    if (verified != true) {
      throw Exception('กรุณายืนยันตัวตน KYC ให้ผ่านก่อนจึงจะส่งใบเสนอราคาได้');
    }

    if (technicianName.trim().isEmpty) {
      throw Exception('กรุณาระบุชื่อช่าง');
    }

    if (price <= 0) {
      throw Exception('กรุณาระบุราคาที่ถูกต้อง');
    }

    if (phone.trim().isEmpty) {
      throw Exception('กรุณาระบุเบอร์โทรศัพท์ช่าง');
    }

    final job = await _client
        .from('job_posts')
        .select('id, status')
        .eq('id', jobPostId)
        .maybeSingle();

    if (job == null || job['status'] != 'open') {
      throw Exception('ประกาศงานนี้ปิดรับแล้ว');
    }

    final existing = await _client
        .from('quotations')
        .select('id')
        .eq('job_post_id', jobPostId)
        .eq('technician_id', _userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('คุณส่งใบเสนอราคางานนี้ไปแล้ว');
    }

    try {
      await _client
          .from('profiles')
          .update({'full_name': technicianName.trim()})
          .eq('id', _userId);
    } catch (_) {}

    await _client.from('quotations').insert({
      'job_post_id': jobPostId,
      'technician_id': _userId,
      'technician_name': technicianName.trim(),
      'price': price,
      'technician_phone': phone.trim(),
      'terms': terms?.trim(),
      'status': 'pending',
    });
  }

  updateQuotation({
    required String quotationId,
    required String technicianName,
    required double price,
    required String phone,
    String? terms,
  }) async {
    if (technicianName.trim().isEmpty) {
      throw Exception('กรุณาระบุชื่อช่าง');
    }
    if (price <= 0) {
      throw Exception('กรุณาระบุราคาที่ถูกต้อง');
    }
    if (phone.trim().isEmpty) {
      throw Exception('กรุณาระบุเบอร์โทรศัพท์ช่าง');
    }

    try {
      await _client
          .from('profiles')
          .update({'full_name': technicianName.trim()})
          .eq('id', _userId);
    } catch (_) {}

    final updated = await _client
        .from('quotations')
        .update({
          'technician_name': technicianName.trim(),
          'price': price,
          'technician_phone': phone.trim(),
          'terms': terms?.trim(),
        })
        .eq('id', quotationId)
        .eq('technician_id', _userId)
        .eq('status', 'pending')
        .select();

    if (List.from(updated).isEmpty) {
      throw Exception('แก้ไขได้เฉพาะใบเสนอราคาที่ยังอยู่ในสถานะ pending');
    }
  }

  cancelQuotation(String quotationId) async {
    final deleted = await _client
        .from('quotations')
        .delete()
        .eq('id', quotationId)
        .eq('technician_id', _userId)
        .eq('status', 'pending')
        .select();

    if (List.from(deleted).isEmpty) {
      throw Exception('ยกเลิกได้เฉพาะใบเสนอราคาที่ยังอยู่ในสถานะ pending');
    }
  }

  getMyQuotations() async {
    final result = await _client
        .from('quotations')
        .select('*, job_posts(title, province, district, status, preferred_at)')
        .eq('technician_id', _userId)
        .order('created_at', ascending: false);

    return List.from(result);
  }

  getJobQuotations(String jobPostId) async {
    final result = await _client
        .from('quotations')
        .select('*, profiles!quotations_technician_id_fkey(full_name)')
        .eq('job_post_id', jobPostId)
        .order('created_at', ascending: true);

    return List.from(result);
  }

  getMyCancellationFeedbacks() async {
    try {
      final rows = await _client
          .from('job_cancellation_feedbacks')
          .select('*, job_posts(title, province, district)')
          .eq('technician_id', _userId)
          .order('created_at', ascending: false);
      return List.from(rows);
    } catch (_) {
      return [];
    }
  }

  acceptQuotation({
    required String quotationId,
    required String jobPostId,
    String? customerName,
    String? customerPhone,
    String? serviceAddress,
    DateTime? scheduledAt,
  }) async {
    final res = await _client.rpc(
      'accept_quotation_and_create_booking',
      params: {
        'p_quotation_id': quotationId,
        'p_job_post_id': jobPostId,
        'p_customer_name': customerName?.trim(),
        'p_customer_phone': customerPhone?.trim(),
        'p_service_address': serviceAddress?.trim(),
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      },
    );

    if (res is Map) {
      return Map.from(res);
    }
    if (res is List && res.isNotEmpty) {
      return Map.from(res.first as Map);
    }
    throw Exception('ไม่สามารถสร้างรายการจองจากใบเสนอราคาได้');
  }
}