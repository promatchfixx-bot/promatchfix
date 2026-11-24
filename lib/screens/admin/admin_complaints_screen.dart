import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/review_complaint_service.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final _service = ReviewComplaintService();
  final _client = Supabase.instance.client;

  var complaints = [];
  var bookingsById = {};
  var bookingsByJobNo = {};
  var profilesById = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final list = await _service.getAllComplaintsForAdmin();
      final complaintList = List.from(list);

      final bById = {};
      final bByJob = {};
      final userIds = <String>{};

      for (final item in complaintList) {
        final c = item as Map;
        final techId = c['technician_id']?.toString() ?? '';
        final custId = c['customer_id']?.toString() ?? '';
        if (techId.isNotEmpty) userIds.add(techId);
        if (custId.isNotEmpty) userIds.add(custId);
      }

      try {
        final bookingRows = await _client.from('bookings').select('*');
        for (final bItem in List.from(bookingRows)) {
          final b = bItem as Map;
          final bId = b['id']?.toString() ?? '';
          final jNo = b['job_number']?.toString().trim() ?? '';
          if (bId.isNotEmpty) bById[bId] = b;
          if (jNo.isNotEmpty) bByJob[jNo] = b;

          final bTech = b['technician_id']?.toString() ?? '';
          final bCust = b['customer_id']?.toString() ?? '';
          if (bTech.isNotEmpty) userIds.add(bTech);
          if (bCust.isNotEmpty) userIds.add(bCust);
        }
      } catch (_) {}

      final pById = {};
      if (userIds.isNotEmpty) {
        try {
          final profileRows = await _client.from('profiles').select('*');
          for (final pItem in List.from(profileRows)) {
            final p = pItem as Map;
            final pid = p['id']?.toString() ?? '';
            if (pid.isNotEmpty && userIds.contains(pid)) {
              pById[pid] = p;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        complaints = complaintList;
        bookingsById = bById;
        bookingsByJobNo = bByJob;
        profilesById = pById;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดข้อร้องเรียนไม่สำเร็จ: $e')));
    }
  }

  Future<void> _changeStatus(String id, String status) async {
    try {
      await _service.updateComplaintStatus(id, status);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('อัปเดตสถานะไม่สำเร็จ: $e')));
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} เวลา $hh:$mm น.';
  }

  String _resolveScheduled(Map complaint, Map? booking) {
    final raw = booking?['scheduled_at']?.toString() ??
        complaint['scheduled_at']?.toString();
    return _formatDateTime(raw);
  }

  String _resolveAddress(Map complaint, Map? booking) {
    final a = booking?['service_address']?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = complaint['service_address']?.toString().trim() ?? '';
    return b.isNotEmpty ? b : '-';
  }

  String _resolveDescription(Map complaint, Map? booking) {
    final a = booking?['description']?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = complaint['job_description']?.toString().trim() ?? '';
    return b.isNotEmpty ? b : '-';
  }

  String _resolveBookingStatus(Map complaint, Map? booking) {
    final a = booking?['status']?.toString().trim() ?? '';
    if (a.isNotEmpty) return a;
    final b = complaint['booking_status']?.toString().trim() ?? '';
    return b.isNotEmpty ? b : '-';
  }

  String _userName(String? id) {
    if (id == null || id.trim().isEmpty) return '-';
    final p = profilesById[id] as Map?;
    final name = p?['full_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return '$name ($id)';
    return id;
  }

  String _userPhone(String? id) {
    if (id == null || id.trim().isEmpty) return '-';
    final p = profilesById[id] as Map?;
    final phone = p?['phone']?.toString().trim() ?? '';
    return phone.isNotEmpty ? phone : '-';
  }

  String _userAvatar(String? id) {
    if (id == null || id.trim().isEmpty) return '';
    final p = profilesById[id] as Map?;
    return p?['avatar_url']?.toString().trim() ?? '';
  }

  Widget _personTile({
    required String label,
    required String name,
    required String avatarUrl,
    String? subtitle,
    IconData fallbackIcon = Icons.person,
  }) {
    final hasAvatar = avatarUrl.isNotEmpty;
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEDE7FF),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
          child: !hasAvatar
              ? Icon(fallbackIcon, size: 18, color: const Color(0xFF7041D8))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label: $name',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty)
                Text(
                  subtitle.trim(),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openJobDetailDialog(Map complaint, Map? booking) async {
    final jobNo = booking?['job_number']?.toString().trim().isNotEmpty == true
        ? booking!['job_number'].toString()
        : (complaint['job_number']?.toString() ?? '-');
    final techId = booking?['technician_id']?.toString() ??
        complaint['technician_id']?.toString();
    final custId = booking?['customer_id']?.toString() ??
        complaint['customer_id']?.toString();
    final address = _resolveAddress(complaint, booking);
    final desc = _resolveDescription(complaint, booking);
    final scheduled = _resolveScheduled(complaint, booking);
    final status = _resolveBookingStatus(complaint, booking);

    var techName = '';
    var techPhone = '';
    final techAvatar = _userAvatar(techId);
    final custAvatar = _userAvatar(custId);

    if (techId != null && techId.trim().isNotEmpty) {
      final p = profilesById[techId] as Map?;
      techName = p?['full_name']?.toString().trim() ?? '';
      techPhone = p?['phone']?.toString().trim() ?? '';
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('รายละเอียดงาน • Job: $jobNo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ช่างผู้รับผิดชอบงาน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _personTile(
                label: 'ชื่อช่าง',
                name: techName.isNotEmpty ? techName : '-',
                avatarUrl: techAvatar,
                subtitle: 'โทร: ${techPhone.isNotEmpty ? techPhone : '-'}',
                fallbackIcon: Icons.build,
              ),
              const SizedBox(height: 4),
              Text('รหัสช่าง: ${techId ?? '-'}'),
              const Divider(height: 18),
              const Text(
                'ข้อมูลงาน',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('สถานะงาน: $status'),
              Text('วันและเวลานัดหมาย: $scheduled'),
              Text('ที่อยู่: $address'),
              Text('รายละเอียดงาน: $desc'),
              const Divider(height: 18),
              const Text(
                'ข้อมูลผู้แจ้ง (ลูกค้า)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _personTile(
                label: 'ลูกค้า',
                name: _userName(custId),
                avatarUrl: custAvatar,
                subtitle: 'โทร: ${_userPhone(custId)}',
                fallbackIcon: Icons.person,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('จัดการข้อร้องเรียน'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : complaints.isEmpty
              ? const Center(child: Text('ยังไม่มีข้อร้องเรียน'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: complaints.length,
                    itemBuilder: (_, index) {
                      final c = complaints[index] as Map;
                      final id = c['id'].toString();
                      final bId = c['booking_id']?.toString() ?? '';
                      final jNoRaw = c['job_number']?.toString().trim() ?? '';
                      final booking = (bookingsById[bId] ??
                          (jNoRaw.isNotEmpty ? bookingsByJobNo[jNoRaw] : null))
                          as Map?;
                      final jobNo = booking?['job_number']?.toString() ??
                          (jNoRaw.isNotEmpty ? jNoRaw : '-');
                      final status = c['status']?.toString() ?? 'pending';
                      final scheduledText = _resolveScheduled(c, booking);
                      final addressText = _resolveAddress(c, booking);
                      final descText = _resolveDescription(c, booking);
                      final subjectText = c['subject']?.toString().trim() ?? '';
                      final detailsText = c['details']?.toString().trim() ?? '';
                      final reasonText = c['reason']?.toString().trim() ?? '';

                      final techId = booking?['technician_id']?.toString() ??
                          c['technician_id']?.toString();
                      final custId = booking?['customer_id']?.toString() ??
                          c['customer_id']?.toString();
                      final custProfile = custId != null
                          ? profilesById[custId] as Map?
                          : null;
                      final techProfile = techId != null
                          ? profilesById[techId] as Map?
                          : null;
                      final custName =
                          custProfile?['full_name']?.toString().trim().isNotEmpty ==
                                  true
                              ? custProfile!['full_name'].toString().trim()
                              : 'ลูกค้า';
                      final techName =
                          techProfile?['full_name']?.toString().trim().isNotEmpty ==
                                  true
                              ? techProfile!['full_name'].toString().trim()
                              : 'ช่าง';

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openJobDetailDialog(c, booking),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Job: $jobNo',
                                      style: const TextStyle(
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Chip(label: Text(status)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _personTile(
                                  label: 'ผู้แจ้ง (ลูกค้า)',
                                  name: custName,
                                  avatarUrl: _userAvatar(custId),
                                  fallbackIcon: Icons.person,
                                ),
                                const SizedBox(height: 8),
                                _personTile(
                                  label: 'ช่างผู้รับผิดชอบ',
                                  name: techName,
                                  avatarUrl: _userAvatar(techId),
                                  fallbackIcon: Icons.build,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'วันและเวลานัดหมาย: $scheduledText',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text('ที่อยู่: $addressText'),
                                if (descText != '-') ...[
                                  const Divider(height: 20),
                                  Text(descText),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subjectText.isNotEmpty
                                            ? 'ข้อร้องเรียน: $subjectText'
                                            : 'ข้อร้องเรียน',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detailsText.isNotEmpty
                                            ? detailsText
                                            : (reasonText.isNotEmpty
                                                  ? reasonText
                                                  : '-'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'แตะเพื่อดูรายละเอียดงานและช่าง',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: Color(0xFFC62828),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          _changeStatus(id, 'investigating'),
                                      child: const Text('กำลังตรวจสอบ'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () =>
                                          _changeStatus(id, 'resolved'),
                                      child: const Text('แก้ไขแล้ว'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}