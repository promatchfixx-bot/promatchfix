import 'package:flutter/material.dart';

import '../services/technician_availability_service.dart';

class TechnicianOnlineToggle extends StatefulWidget {
  const TechnicianOnlineToggle({super.key});

  @override
  State<TechnicianOnlineToggle> createState() => _TechnicianOnlineToggleState();
}

class _TechnicianOnlineToggleState extends State<TechnicianOnlineToggle> {
  final service = TechnicianAvailabilityService();

  bool isOnline = false;
  bool loading = true;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  Future<void> loadStatus() async {
    try {
      final status = await service.getOnlineStatus();

      if (!mounted) return;

      setState(() {
        isOnline = status;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> toggleStatus(bool value) async {
    if (updating) return;

    setState(() => updating = true);

    try {
      await service.setOnline(value);

      if (!mounted) return;

      setState(() {
        isOnline = value;
        updating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'เปิดรับงานเรียบร้อยแล้ว' : 'ปิดรับงานเรียบร้อยแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => updating = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      elevation: 0,
      color: isOnline ? const Color(0xFFE8F7EE) : const Color(0xFFF1F1F5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: isOnline ? Colors.green : Colors.grey,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'กำลังเปิดรับงาน' : 'ปิดรับงานอยู่',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline
                        ? 'ลูกค้าสามารถค้นหาคุณได้'
                        : 'คุณจะไม่แสดงในรายการค้นหาช่าง',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (updating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(value: isOnline, onChanged: toggleStatus),
          ],
        ),
      ),
    );
  }
}
