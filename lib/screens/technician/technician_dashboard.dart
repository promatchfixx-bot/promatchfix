import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/technician_online_toggle.dart';
import 'kyc_screen.dart';
import 'subscription_screen.dart';
import 'technician_job_board_screen.dart';
import 'technician_jobs_screen.dart';
import 'technician_location_screen.dart';
import 'technician_profile_screen.dart';
import 'technician_service_catalog_screen.dart';

class TechnicianDashboard extends StatelessWidget {
  const TechnicianDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Technician Portal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TechnicianOnlineToggle(),
              const SizedBox(height: 16),
              const Text(
                'แดชบอร์ดช่าง',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF7041D8),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ยืนยันตัวตนช่าง',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'กรุณาดำเนินการยืนยันตัวตน '
                      'เพื่อเปิดใช้งานความสามารถสำหรับช่าง',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    const Chip(
                      avatar: Icon(Icons.info_outline, size: 18),
                      label: Text('โปรดตรวจสอบสถานะ KYC'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KycScreen()),
                        );
                      },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('ยืนยันตัวตนตอนนี้'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'จัดการงานของฉัน',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _TechnicianMenu(
                icon: Icons.calendar_month_outlined,
                title: 'คิวงานและงานที่ได้รับ',
                subtitle: 'ดูรายการงานประจำวัน ',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TechnicianJobsScreen(),
                    ),
                  );
                },
              ),
              _TechnicianMenu(
                icon: Icons.work_outline,
                title: 'บอร์ดประกาศงาน',
                subtitle: 'ค้นหางานและส่งใบเสนอราคา',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TechnicianJobBoardScreen(),
                    ),
                  );
                },
              ),
              _TechnicianMenu(
                icon: Icons.person_outline,
                title: 'โปรไฟล์ช่าง',
                subtitle: 'จัดการข้อมูลส่วนตัว',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TechnicianProfileScreen(),
                    ),
                  );
                },
              ),
              Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.workspace_premium_outlined,
                    color: Color(0xFF7041D8),
                  ),
                  title: const Text('สมาชิกและแพ็กเกจ'),
                  subtitle: const Text('ระบบสมาชิกช่างรายเดือน'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    );
                  },
                ),
              ),
              Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFE8FF),
                    child: Icon(
                      Icons.price_change_outlined,
                      color: Color(0xFF7041D8),
                    ),
                  ),
                  title: const Text('บอร์ดโพสต์เสนองานช่าง'),
                  subtitle: const Text('โพสต์นำเสนองานของคุณ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicianServiceCatalogScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicianLocationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('จัดการตำแหน่งและการรับงาน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechnicianMenu extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _TechnicianMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF7041D8)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}