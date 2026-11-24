import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_bookings_screen.dart';
import 'customer_find_technician_screen.dart';
import 'customer_job_posts_screen.dart';
import 'customer_profile_screen.dart';
import 'technician_map_screen.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  static const Color primary = Color(0xFF7041D8);

  void _openFindTechnician(BuildContext context, {String? query}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFindTechnicianScreen(initialQuery: query),
      ),
    );
  }

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
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openFindTechnician(context),
                child: Container(
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
                'เมนูการใช้งาน',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _MenuItem(
                icon: Icons.search,
                title: 'ค้นหาช่าง',
                subtitle: 'ค้นหาช่างตามประเภทงาน',
                onTap: () => _openFindTechnician(context),
              ),
              _MenuItem(
                icon: Icons.assignment_outlined,
                title: 'ประกาศงาน',
                subtitle: 'ลงประกาศงานเพื่อหาช่าง',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerJobPostsScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.calendar_month_outlined,
                title: 'การจองของฉัน',
                subtitle: 'ตรวจสอบรายการนัดหมาย',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerBookingsScreen(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.person_outline,
                title: 'โปรไฟล์ของฉัน',
                subtitle: 'จัดการข้อมูลส่วนตัว',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerProfileScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
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
                children: [
                  _ServiceItem(
                    Icons.electrical_services,
                    'ช่างไฟฟ้า',
                    onTap: () => _openFindTechnician(context, query: 'ไฟฟ้า'),
                  ),
                  _ServiceItem(
                    Icons.water_drop_outlined,
                    'ช่างประปา',
                    onTap: () => _openFindTechnician(context, query: 'ประปา'),
                  ),
                  _ServiceItem(
                    Icons.ac_unit,
                    'ช่างแอร์',
                    onTap: () => _openFindTechnician(context, query: 'แอร์'),
                  ),
                  _ServiceItem(
                    Icons.home_repair_service,
                    'ช่างซ่อมบ้าน',
                    onTap: () => _openFindTechnician(context, query: 'ซ่อมบ้าน'),
                  ),
                  _ServiceItem(
                    Icons.camera_alt_outlined,
                    'กล้องวงจรปิด',
                    onTap: () =>
                        _openFindTechnician(context, query: 'กล้องวงจรปิด'),
                  ),
                  _ServiceItem(
                    Icons.cleaning_services,
                    'แม่บ้าน',
                    onTap: () => _openFindTechnician(context, query: 'แม่บ้าน'),
                  ),
                  _ServiceItem(
                    Icons.window_outlined,
                    'กระจกอลูมิเนียม',
                    onTap: () => _openFindTechnician(context, query: 'กระจก'),
                  ),
                  _ServiceItem(
                    Icons.water_damage_outlined,
                    'รางน้ำ',
                    onTap: () => _openFindTechnician(context, query: 'รางน้ำ'),
                  ),
                  _ServiceItem(
                    Icons.pool_outlined,
                    'สระว่ายน้ำ',
                    onTap: () =>
                        _openFindTechnician(context, query: 'สระว่ายน้ำ'),
                  ),
                ],
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
  final VoidCallback? onTap;

  const _ServiceItem(this.icon, this.title, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
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
        leading: Icon(icon, color: CustomerDashboard.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}