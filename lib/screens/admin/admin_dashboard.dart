
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ผู้ดูแลระบบ',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? ''),
            const SizedBox(height: 24),
            const _AdminItem(
              icon: Icons.people_outline,
              title: 'จัดการสมาชิก',
            ),
            const _AdminItem(
              icon: Icons.verified_user_outlined,
              title: 'ตรวจสอบ KYC',
            ),
            const _AdminItem(
              icon: Icons.rate_review_outlined,
              title: 'ตรวจสอบรีวิว',
            ),
            const _AdminItem(
              icon: Icons.report_outlined,
              title: 'จัดการข้อร้องเรียน',
            ),
            const _AdminItem(
              icon: Icons.payments_outlined,
              title: 'ตรวจสอบการชำระเงิน',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _AdminItem({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF16834D),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
