
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    if (role != 'customer' && role != 'technician') {
      throw Exception('ประเภทบัญชีไม่ถูกต้อง');
    }

    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role,
      },
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) return null;

    return await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Stream<AuthState> get authChanges =>
      _client.auth.onAuthStateChange;
}
