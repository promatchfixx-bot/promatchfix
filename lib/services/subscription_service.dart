import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_model.dart';

class SubscriptionService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>> createPayment() async {
    final response = await _client.functions.invoke(
      'create-subscription-payment',
      body: {},
    );

    if (response.status < 200 || response.status >= 300) {
      throw Exception('ไม่สามารถสร้างรายการชำระเงินได้');
    }

    if (response.data is! Map || response.data['success'] != true) {
      throw Exception('ไม่สามารถสร้าง QR Code ได้');
    }

    return Map<String, dynamic>.from(response.data);
  }

  Future<TechnicianSubscription?> getCurrentSubscription() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('กรุณาเข้าสู่ระบบ');
    }

    final result = await _client
        .from('subscriptions')
        .select()
        .eq('technician_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (result == null) return null;

    return TechnicianSubscription.fromMap(result);
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('กรุณาเข้าสู่ระบบ');
    }

    final result = await _client
        .from('payments')
        .select('id, amount, status, provider, created_at, paid_at')
        .eq('technician_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }
}
