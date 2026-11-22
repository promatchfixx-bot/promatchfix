import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final client = Supabase.instance.client;

  Map<String, dynamic> report = {};
  List<Map<String, dynamic>> logs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final summary = await client.rpc('admin_report_summary');

      final audit = await client
          .from('admin_audit_logs')
          .select('action, target_user_id, details, created_at')
          .order('created_at', ascending: false)
          .limit(30);

      if (!mounted) return;

      setState(() {
        report = Map<String, dynamic>.from(summary);
        logs = List<Map<String, dynamic>>.from(audit);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดรายงานไม่สำเร็จ: $e')));
    }
  }

  Widget metric(String title, String value, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7041D8)),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('รายงานระบบ'),
        backgroundColor: Colors.white,
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'ภาพรวมสมาชิก',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      metric(
                        'สมาชิกทั้งหมด',
                        '${report['total_users'] ?? 0}',
                        Icons.people,
                      ),
                      metric(
                        'ช่าง',
                        '${report['total_technicians'] ?? 0}',
                        Icons.build,
                      ),
                      metric(
                        'ลูกค้า',
                        '${report['total_customers'] ?? 0}',
                        Icons.person,
                      ),
                      metric(
                        'บัญชีถูกระงับ',
                        '${report['suspended_users'] ?? 0}',
                        Icons.block,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ภาพรวมสมาชิกแบบชำระเงิน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      metric(
                        'สมาชิกใช้งานอยู่',
                        '${report['active_subscriptions'] ?? 0}',
                        Icons.verified,
                      ),
                      metric(
                        'รอชำระเงิน',
                        '${report['pending_payments'] ?? 0}',
                        Icons.pending_actions,
                      ),
                      metric(
                        'ชำระเงินสำเร็จ',
                        '${report['successful_payments'] ?? 0}',
                        Icons.payments,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ประวัติการดำเนินการ Admin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...logs.map(
                    (log) => Card(
                      color: Colors.white,
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: Color(0xFF7041D8),
                        ),
                        title: Text(log['action'] ?? '-'),
                        subtitle: Text(
                          '${log['created_at'] ?? ''}\n'
                          'User: ${log['target_user_id'] ?? '-'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
