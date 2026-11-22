import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KycManagementScreen extends StatefulWidget {
  const KycManagementScreen({super.key});

  @override
  State<KycManagementScreen> createState() => _KycManagementScreenState();
}

class _KycManagementScreenState extends State<KycManagementScreen> {
  final client = Supabase.instance.client;

  bool loading = true;
  final List<dynamic> submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => loading = true);

    try {
      final result = await client
          .from('technician_kyc')
          .select()
          .eq('status', 'pending')
          .order('submitted_at');

      if (!mounted) return;

      setState(() {
        submissions
          ..clear()
          ..addAll(result);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _message('โหลดรายการไม่สำเร็จ: $e');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _review(Map<String, dynamic> item, String status) async {
    String? reason;

    if (status == 'rejected') {
      reason = await _rejectionDialog();
      if (reason == null || reason.trim().isEmpty) return;
    }

    try {
      final adminId = client.auth.currentUser?.id;

      if (adminId == null) {
        throw Exception('กรุณาเข้าสู่ระบบ');
      }

      await client
          .from('technician_kyc')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            'reviewed_by': adminId,
            'rejection_reason': reason,
          })
          .eq('id', item['id'])
          .eq('status', 'pending');

      _message(
        status == 'approved' ? 'อนุมัติ KYC เรียบร้อย' : 'ปฏิเสธ KYC เรียบร้อย',
      );

      await _loadSubmissions();
    } catch (e) {
      _message('ดำเนินการไม่สำเร็จ: $e');
    }
  }

  Future<String?> _rejectionDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ระบุเหตุผลที่ไม่อนุมัติ'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'เช่น รูปบัตรไม่ชัดเจน',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _showDocument(String path) async {
    try {
      final imageUrl = await client.storage
          .from('technician-kyc')
          .createSignedUrl(path, 60);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เอกสารยืนยันตัวตน'),
          content: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text('ไม่สามารถเปิดรูปได้'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('เปิดเอกสารไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('ตรวจสอบ KYC'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadSubmissions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : submissions.isEmpty
          ? const Center(child: Text('ไม่มีรายการรอตรวจสอบ'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final item = submissions[index];

                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ผู้สมัคร: ${item['technician_id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('เลขบัตรลงท้าย: ****${item['national_id_last4']}'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showDocument(item['card_image_path']),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('ดูรูปบัตร'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _review(item, 'rejected'),
                                child: const Text('ปฏิเสธ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _review(item, 'approved'),
                                child: const Text('อนุมัติ'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
