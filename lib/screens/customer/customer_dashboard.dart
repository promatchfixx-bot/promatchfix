import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'technician_map_screen.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  static const Color primary = Color(0xFF7041D8);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Promatchfix',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
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
                'สวัสดี ยินดีต้อนรับ',
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
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'ค้นหาช่างที่คุณต้องการ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ค้นหาช่างและบริการใกล้บ้านคุณ',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicianMapScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('ค้นหาช่างบนแผนที่'),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'บริการของเรา',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: const [
                  _ServiceItem(Icons.electrical_services, 'ช่างไฟฟ้า'),
                  _ServiceItem(Icons.water_drop_outlined, 'ช่างประปา'),
                  _ServiceItem(Icons.ac_unit, 'ช่างแอร์'),
                  _ServiceItem(Icons.home_repair_service, 'ช่างซ่อมบ้าน'),
                  _ServiceItem(Icons.camera_alt_outlined, 'กล้องวงจรปิด'),
                  _ServiceItem(Icons.cleaning_services, 'แม่บ้าน'),
                  _ServiceItem(Icons.window_outlined, 'กระจกอลูมิเนียม'),
                  _ServiceItem(Icons.water_damage_outlined, 'รางน้ำ'),
                  _ServiceItem(Icons.pool_outlined, 'สระว่ายน้ำ'),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'เมนูการใช้งาน',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const _MenuItem(
                icon: Icons.search,
                title: 'ค้นหาช่าง',
                subtitle: 'ค้นหาช่างตามประเภทและพื้นที่',
              ),
              const _MenuItem(
                icon: Icons.assignment_outlined,
                title: 'ประกาศงาน',
                subtitle: 'ลงประกาศงานซ่อมและติดตั้ง',
              ),
              const _MenuItem(
                icon: Icons.calendar_month_outlined,
                title: 'การจองของฉัน',
                subtitle: 'ตรวจสอบรายการนัดหมาย',
              ),
              const _MenuItem(
                icon: Icons.person_outline,
                title: 'โปรไฟล์ของฉัน',
                subtitle: 'จัดการข้อมูลส่วนตัว',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ServiceItem(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: CustomerDashboard.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MenuItem({
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
        leading: Icon(icon, color: CustomerDashboard.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
