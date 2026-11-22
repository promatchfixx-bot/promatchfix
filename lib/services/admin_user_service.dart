import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user_model.dart';

class AdminUserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AdminUser>> getUsers({
    String? role,
    String? keyword,
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final safePage = page < 0 ? 0 : page;
    final start = safePage * pageSize;
    final end = start + pageSize - 1;

    var query = _client
        .from('profiles')
        .select('id, full_name, phone, role, account_status, created_at');

    if (role != null && role != 'all') {
      query = query.eq('role', role);
    }

    if (status != null && status != 'all') {
      query = query.eq('account_status', status);
    }

    final trimmedKeyword = keyword?.trim();

    if (trimmedKeyword != null && trimmedKeyword.isNotEmpty) {
      final term = trimmedKeyword.replaceAll(',', ' ');
      query = query.ilike('full_name', '%$term%');
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(start, end);

    final users = <AdminUser>[];

    for (final item in rows) {
      users.add(AdminUser.fromMap(Map<String, dynamic>.from(item)));
    }

    return users;
  }

  Future<List<Map<String, dynamic>>> getUsersRaw({
    String? search,
    String? role,
    String? status,
  }) async {
    var query = _client.from('profiles').select();

    if (role != null && role != 'all') {
      query = query.eq('role', role);
    }

    if (status != null && status != 'all') {
      query = query.eq('account_status', status);
    }

    final trimmedSearch = search?.trim();

    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      final term = trimmedSearch.replaceAll(',', '');
      query = query.ilike('full_name', '%$term%');
    }

    final rows = await query.order('created_at', ascending: false);

    final list = <Map<String, dynamic>>[];

    for (final item in rows) {
      list.add(Map<String, dynamic>.from(item));
    }

    return list;
  }

  Future<Map<String, dynamic>> getUserDetail(String id) async {
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .single();

    Map<String, dynamic>? technician;

    if (profile['role'] == 'technician') {
      technician = await _client
          .from('technician_profiles')
          .select()
          .eq('user_id', id)
          .maybeSingle();

      technician ??= await _client
          .from('technician_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
    }

    return {'profile': profile, 'technician': technician};
  }

  Future<void> changeAccountStatus({
    required String targetUserId,
    required String action,
    required String reason,
  }) async {
    final response = await _client.functions.invoke(
      'admin-manage-user',
      body: {
        'target_user_id': targetUserId,
        'action': action,
        'reason': reason,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;

      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'ไม่สามารถเปลี่ยนสถานะบัญชีได้';

      throw Exception(message);
    }

    if (response.data is Map && response.data['success'] != true) {
      final data = response.data as Map;

      final message = data['error'] != null
          ? data['error'].toString()
          : 'การดำเนินการไม่สำเร็จ';

      throw Exception(message);
    }
  }

  Future<void> manageUser({
    required String userId,
    required String action,
    String? reason,
  }) async {
    await changeAccountStatus(
      targetUserId: userId,
      action: action,
      reason: (reason ?? '').trim(),
    );
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    final rows = await _client
        .from('admin_audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    final logs = <Map<String, dynamic>>[];

    for (final item in rows) {
      logs.add(Map<String, dynamic>.from(item));
    }

    return logs;
  }

  Future<Map<String, int>> getUserStatistics() async {
    final rows = await _client.from('profiles').select('role, account_status');

    var total = 0;
    var customers = 0;
    var technicians = 0;
    var suspended = 0;
    var active = 0;

    for (final item in rows) {
      final row = Map<String, dynamic>.from(item);

      total++;

      if (row['role'] == 'customer') customers++;
      if (row['role'] == 'technician') technicians++;
      if (row['account_status'] == 'suspended') suspended++;
      if (row['account_status'] == 'active') active++;
    }

    return {
      'total': total,
      'customers': customers,
      'technicians': technicians,
      'suspended': suspended,
      'active': active,
    };
  }
}
