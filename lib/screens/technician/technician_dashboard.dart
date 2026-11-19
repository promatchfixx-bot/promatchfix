
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
              const Text(
                'แดชบอร์ดช่าง',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
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
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF7041D8),
                      size: 36,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'ยืนยันตัวตนช่าง',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'กรุณาดำเนินการยืนยันตัวตน '
                      'เพื่อเปิดใช้งานความสามารถสำหรับช่าง',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 12),
                    Chip(
                      avatar: Icon(
                        Icons.info_outline,
                        size: 18,
                      ),
                      label: Text('โปรดตรวจสอบสถานะ KYC'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'จัดการงานของฉัน',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const _TechnicianMenu(
                icon: Icons.calendar_month_outlined,
                title: 'คิวงานประจำวัน',
                subtitle: 'ดูรายการนัดหมายของแต่ละวัน',
              ),
              const _TechnicianMenu(
                icon: Icons.assignment_outlined,
                title: 'งานที่ได้รับ',
                subtitle: 'ตรวจสอบ Job Number และรายละเอียดงาน',
              ),
              const _TechnicianMenu(
                icon: Icons.work_outline,
                title: 'บอร์ดประกาศงาน',
                subtitle: 'ค้นหางานและส่งใบเสนอราคา',
              ),
              const _TechnicianMenu(
                icon: Icons.person_outline,
                title: 'โปรไฟล์ช่าง',
                subtitle: 'จัดการข้อมูลและค่าบริการ',
              ),
              const _TechnicianMenu(
                icon: Icons.credit_card_outlined,
                title: 'สมาชิกของฉัน',
                subtitle: 'ตรวจสอบวันหมดอายุสมาชิก',
              ),
              const _TechnicianMenu(
                icon: Icons.toggle_on_outlined,
                title: 'สถานะการรับงาน',
                subtitle: 'จัดการสถานะออนไลน์และออฟไลน์',
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

  const _TechnicianMenu({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF7041D8),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
