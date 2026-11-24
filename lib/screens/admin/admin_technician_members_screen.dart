import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTechnicianMembersScreen extends StatefulWidget {
  const AdminTechnicianMembersScreen({super.key});

  @override
  State<AdminTechnicianMembersScreen> createState() =>
      _AdminTechnicianMembersScreenState();
}

class _AdminTechnicianMembersScreenState
    extends State<AdminTechnicianMembersScreen> {
  static const Color primary = Color(0xFF7041D8);
  static const Color accent = Color(0xFF16834D);

  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _statusFilter = 'all'; // 'all' | 'active' | 'inactive'
  var _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _extractTechId(Map row) {
    for (final key in const ['technician_id', 'user_id', 'profile_id', 'id']) {
      final val = row[key]?.toString().trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    return '';
  }

  DateTime? _extractStartDate(Map row) {
    for (final key in const [
      'starts_at',
      'start_date',
      'started_at',
      'current_period_start',
      'created_at',
    ]) {
      final dt = _parseDate(row[key]);
      if (dt != null) return dt;
    }
    return null;
  }

  DateTime? _extractEndDate(Map row) {
    for (final key in const [
      'expires_at',
      'end_date',
      'ended_at',
      'current_period_end',
      'expired_at',
    ]) {
      final dt = _parseDate(row[key]);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isMemberActive(Map? subRow, DateTime? endDate) {
    if (subRow == null) return false;

    final statusRaw = (subRow['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isActiveFlag = subRow['is_active'];

    if (statusRaw == 'cancelled' ||
        statusRaw == 'canceled' ||
        statusRaw == 'expired' ||
        statusRaw == 'inactive') {
      return false;
    }
    if (isActiveFlag is bool && !isActiveFlag) {
      return false;
    }
    if (endDate != null) {
      return endDate.toLocal().isAfter(DateTime.now());
    }
    return statusRaw == 'active' || isActiveFlag == true;
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);

    try {
      // 1. ดึงโปรไฟล์ช่างทั้งหมดจากตาราง profiles (role = technician)
      final techProfilesById = <String, Map>{};
      try {
        final pRows = await _client
            .from('profiles')
            .select('id, full_name, avatar_url, phone, role')
            .eq('role', 'technician');
        for (final p in List.from(pRows)) {
          if (p is Map) {
            final pid = p['id']?.toString().trim() ?? '';
            if (pid.isNotEmpty) {
              techProfilesById[pid] = Map.from(p);
            }
          }
        }
      } catch (_) {}

      // 2. ดึงข้อมูลการสมัครสมาชิกจากตารางที่ระบบใช้
      var subRows = [];
      for (final tableName in const [
        'technician_subscriptions',
        'subscriptions',
      ]) {
        try {
          final res = await _client.from(tableName).select('*');
          subRows = List.from(res);
          if (subRows.isNotEmpty) break;
        } catch (_) {}
      }

      // เก็บรายการสมัครล่าสุดต่อ 1 บัญชีช่าง
      final latestSubByTechId = <String, Map>{};
      for (final item in subRows) {
        if (item is! Map) continue;
        final row = Map.from(item);
        final tid = _extractTechId(row);
        if (tid.isEmpty) continue;

        final startDt = _extractStartDate(row);
        final endDt = _extractEndDate(row);
        row['_start_dt'] = startDt;
        row['_end_dt'] = endDt;

        final existing = latestSubByTechId[tid];
        if (existing == null) {
          latestSubByTechId[tid] = row;
        } else {
          final oldStart = existing['_start_dt'] as DateTime?;
          if (startDt != null &&
              (oldStart == null || startDt.isAfter(oldStart))) {
            latestSubByTechId[tid] = row;
          }
        }
      }

      // ถ้ามี id ใน subscription ที่ยังไม่อยู่ใน techProfilesById ให้ดึงเพิ่มจาก profiles
      final missingIds = latestSubByTechId.keys
          .where((id) => !techProfilesById.containsKey(id))
          .toList();
      if (missingIds.isNotEmpty) {
        try {
          final extraRows = await _client
              .from('profiles')
              .select('id, full_name, avatar_url, phone, role')
              .inFilter('id', missingIds);
          for (final p in List.from(extraRows)) {
            if (p is Map) {
              final pid = p['id']?.toString().trim() ?? '';
              if (pid.isNotEmpty) {
                techProfilesById[pid] = Map.from(p);
              }
            }
          }
        } catch (_) {}
      }

      // 3. รวมรายชื่อช่างทั้งหมด (ไม่ซ้ำคน)
      final allTechIds = <String>{
        ...techProfilesById.keys,
        ...latestSubByTechId.keys,
      };

      final combined = [];
      for (final tid in allTechIds) {
        final profile = techProfilesById[tid];
        final sub = latestSubByTechId[tid];
        final startDt = sub?['_start_dt'] as DateTime?;
        final endDt = sub?['_end_dt'] as DateTime?;
        final active = _isMemberActive(sub, endDt);

        combined.add({
          'tech_id': tid,
          'profile': profile,
          'sub': sub,
          'start_dt': startDt,
          'end_dt': endDt,
          'is_active': active,
          'has_sub': sub != null,
        });
      }

      // เรียงสมาชิกที่ใช้งานอยู่ขึ้นก่อน แล้วตามด้วยชื่อ
      combined.sort((a, b) {
        final ma = a as Map;
        final mb = b as Map;
        final aActive = (ma['is_active'] == true) ? 0 : 1;
        final bActive = (mb['is_active'] == true) ? 0 : 1;
        if (aActive != bActive) return aActive.compareTo(bActive);

        final nameA = ((ma['profile'] as Map?)?['full_name'] ?? '')
            .toString()
            .toLowerCase();
        final nameB = ((mb['profile'] as Map?)?['full_name'] ?? '')
            .toString()
            .toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (!mounted) return;
      setState(() {
        _members = combined;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดข้อมูลสมาชิกช่างไม่สำเร็จ: $e')),
      );
    }
  }

  List _getFilteredMembers() {
    final q = _searchController.text.trim().toLowerCase();

    return _members.where((item) {
      final row = item as Map;
      final active = row['is_active'] == true;
      if (_statusFilter == 'active' && !active) return false;
      if (_statusFilter == 'inactive' && active) return false;

      if (q.isEmpty) return true;
      final profile = row['profile'] as Map?;
      final sub = row['sub'] as Map?;
      final name = (profile?['full_name']?.toString() ?? '').toLowerCase();
      final phone = (profile?['phone']?.toString() ?? '').toLowerCase();
      final plan = (sub?['plan_name'] ?? sub?['plan'] ?? '')
          .toString()
          .toLowerCase();
      final tid = (row['tech_id']?.toString() ?? '').toLowerCase();

      return name.contains(q) ||
          phone.contains(q) ||
          plan.contains(q) ||
          tid.contains(q);
    }).toList();
  }

  Widget _summaryCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        _members.where((m) => (m as Map)['is_active'] == true).length;
    final inactiveCount = _members.length - activeCount;
    final visibleList = _getFilteredMembers();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('สมาชิกช่างรายเดือน'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadMembers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMembers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _summaryCard(
                        'ช่างทั้งหมด',
                        _members.length,
                        primary,
                        Icons.engineering_outlined,
                      ),
                      const SizedBox(width: 10),
                      _summaryCard(
                        'สมาชิกใช้งานอยู่',
                        activeCount,
                        accent,
                        Icons.verified_outlined,
                      ),
                      const SizedBox(width: 10),
                      _summaryCard(
                        'ไม่ใช้งาน/หมดอายุ',
                        inactiveCount,
                        Colors.orange.shade700,
                        Icons.history_toggle_off,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อช่าง, เบอร์โทร หรือแพ็กเกจ',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('ทั้งหมด'),
                        selected: _statusFilter == 'all',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('สมาชิกใช้งานอยู่'),
                        selected: _statusFilter == 'active',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'active'),
                      ),
                      ChoiceChip(
                        label: const Text('ไม่ใช้งาน/หมดอายุ'),
                        selected: _statusFilter == 'inactive',
                        onSelected: (_) =>
                            setState(() => _statusFilter = 'inactive'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (visibleList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('ไม่พบข้อมูลช่างในระบบ'),
                      ),
                    )
                  else
                    ...visibleList.map((item) {
                      final row = item as Map;
                      final profile = row['profile'] as Map?;
                      final sub = row['sub'] as Map?;

                      final rawName =
                          profile?['full_name']?.toString().trim() ?? '';
                      final displayName =
                          rawName.isNotEmpty ? rawName : 'ไม่ระบุชื่อ';
                      final phone =
                          profile?['phone']?.toString().trim() ?? '';
                      final avatarUrl =
                          profile?['avatar_url']?.toString().trim() ?? '';
                      final hasAvatar = avatarUrl.isNotEmpty;

                      final hasSub = row['has_sub'] == true;
                      final active = row['is_active'] == true;
                      final planName = hasSub
                          ? ((sub?['plan_name'] ??
                                      sub?['plan'] ??
                                      'แพ็กเกจช่างรายเดือน')
                                  .toString()
                                  .trim())
                          : 'ยังไม่ได้สมัครแพ็กเกจรายเดือน';
                      final startDt = row['start_dt'] as DateTime?;
                      final endDt = row['end_dt'] as DateTime?;

                      final badgeLabel = active
                          ? 'ใช้งานอยู่'
                          : (hasSub ? 'หมดอายุ' : 'ยังไม่เป็นสมาชิก');

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFEFE8FF),
                                    backgroundImage: hasAvatar
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: !hasAvatar
                                        ? const Icon(
                                            Icons.build,
                                            color: primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'ช่าง • ${phone.isNotEmpty ? phone : '-'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    backgroundColor: active
                                        ? const Color(0xFFE6F6EC)
                                        : const Color(0xFFFFF3E0),
                                    side: BorderSide.none,
                                    label: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: active
                                            ? accent
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Text(
                                'แพ็กเกจ: $planName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'วันเริ่มเป็นสมาชิก: ${_formatDate(startDt)}  •  วันสิ้นสุด: ${_formatDate(endDt)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}