
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

import '../customer/customer_dashboard.dart';
import '../technician/technician_dashboard.dart';
import '../admin/admin_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Map<String, dynamic>?> _getProfile(
    String userId,
  ) async {
    return await Supabase.instance.client
        .from('profiles')
        .select('id, full_name, role')
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = client.auth.currentUser;

        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.id),
          future: _getProfile(user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'ไม่สามารถโหลดข้อมูลบัญชีได้',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${profileSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            (context as Element).markNeedsBuild();
                          },
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;

            if (profile == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'ไม่พบข้อมูลโปรไฟล์ กรุณาติดต่อผู้ดูแลระบบ',
                  ),
                ),
              );
            }

            final role = profile['role'];

            switch (role) {
              case 'customer':
                return const CustomerDashboard();

              case 'technician':
                return const TechnicianDashboard();

              case 'admin':
                return const AdminDashboard();

              default:
                return const Scaffold(
                  body: Center(
                    child: Text('ไม่พบประเภทบัญชีที่ถูกต้อง'),
                  ),
                );
            }
          },
        );
      },
    );
  }
}
