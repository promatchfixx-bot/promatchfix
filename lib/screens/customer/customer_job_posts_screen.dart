import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/job_board_service.dart';

class CustomerJobPostsScreen extends StatefulWidget {
  const CustomerJobPostsScreen({super.key});

  @override
  State<CustomerJobPostsScreen> createState() => _CustomerJobPostsScreenState();
}

class _CustomerJobPostsScreenState extends State<CustomerJobPostsScreen> {
  final service = JobBoardService();
  final _client = Supabase.instance.client;

  List<dynamic> jobs = [];
  List<dynamic> categories = [];
  Set<String> _inProgressJobIds = {};

  bool loading = true;

  static const primary = Color(0xFF7041D8);

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() async {
    setState(() => loading = true);

    try {
      final myJobs = await service.getMyJobPosts();
      final allCategories = await service.getCategories();
      final uid = _client.auth.currentUser?.id;
      Set<String> inProgressIds = {};

      if (uid != null) {
        final activeBookings = await _client
            .from('bookings')
            .select('job_post_id, status')
            .eq('customer_id', uid)
            .eq('status', 'in_progress');
        inProgressIds = List.from(activeBookings)
            .map((e) => (e as Map)['job_post_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      if (!mounted) return;

      setState(() {
        jobs = List<dynamic>.from(myJobs as List);
        categories = List<dynamic>.from(allCategories as List);
        _inProgressJobIds = inProgressIds;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      message('โหลดข้อมูลไม่สำเร็จ: $e');
    }
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} เวลา $hh:$mm น.';
  }

  Map<String, Map<String, dynamic>> _loadTechnicianProfiles(
    List<dynamic> quotations,
  ) {
    final map = <String, Map<String, dynamic>>{};

    for (final item in quotations) {
      if (item is! Map) continue;
      final tid = item['technician_id']?.toString().trim() ?? '';
      final nested = item['profiles'];
      if (nested is Map && tid.isNotEmpty) {
        map[tid] = Map<String, dynamic>.from(nested);
      }
    }

    return map;
  }

  void _syncTechnicianProfilesFromDb(
    List<dynamic> quotations,
    Map<String, Map<String, dynamic>> targetMap,
    VoidCallback onUpdated,
  ) async {
    final ids = <String>{};
    for (final item in quotations) {
      if (item is! Map) continue;
      final tid = item['technician_id']?.toString().trim() ?? '';
      if (tid.isNotEmpty) ids.add(tid);
    }
    if (ids.isEmpty) return;

    try {
      final rows = await _client
          .from('profiles')
          .select('id, full_name, avatar_url, phone')
          .inFilter('id', ids.toList());

      for (final row in List.from(rows)) {
        if (row is Map) {
          final pid = row['id']?.toString().trim() ?? '';
          if (pid.isNotEmpty) {
            targetMap[pid] = {
              ...?targetMap[pid],
              ...Map<String, dynamic>.from(row),
            };
          }
        }
      }

      if (mounted) {
        onUpdated();
      }
    } catch (_) {}
  }

  Widget _technicianAvatarAndName({
    required Map quote,
    required Map<String, Map<String, dynamic>> profilesById,
  }) {
    final tid = quote['technician_id']?.toString().trim() ?? '';
    final profile = tid.isNotEmpty ? profilesById[tid] : null;
    final nested = quote['profiles'] is Map ? quote['profiles'] as Map : null;

    final rawName = quote['technician_name']?.toString().trim() ??
        profile?['full_name']?.toString().trim() ??
        nested?['full_name']?.toString().trim() ??
        '';
    final displayName = rawName.isNotEmpty ? rawName : 'ช่าง';

    final rawAvatar = profile?['avatar_url']?.toString().trim() ??
        nested?['avatar_url']?.toString().trim() ??
        quote['technician_avatar_url']?.toString().trim() ??
        '';
    final hasAvatar = rawAvatar.isNotEmpty;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEDE7FF),
          backgroundImage: hasAvatar ? NetworkImage(rawAvatar) : null,
          child: !hasAvatar
              ? const Icon(
                  Icons.engineering,
                  size: 18,
                  color: primary,
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(Map job) {
    final jobId = job['id']?.toString() ?? '';
    if (_inProgressJobIds.contains(jobId)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          'ช่างกำลังดำเนินงานอยู่',
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final status = job['status']?.toString() ?? 'open';
    if (status == 'assigned') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Text(
          'จ้างแล้ว',
          style: TextStyle(
            color: Colors.purple.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    final isOpen = status == 'open';
    final bgColor = isOpen ? Colors.green.shade50 : Colors.red.shade50;
    final borderColor = isOpen ? Colors.green.shade300 : Colors.red.shade300;
    final textColor = isOpen ? Colors.green.shade800 : Colors.red.shade800;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _toggleStatus(job),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          isOpen ? 'เปิดรับ' : 'ปิดรับ',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _openJobForm({Map? existingJob}) async {
    final isEdit = existingJob != null;
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(
      text: existingJob?['title']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: existingJob?['description']?.toString() ?? '',
    );
    final province = TextEditingController(
      text: existingJob?['province']?.toString() ?? '',
    );
    final district = TextEditingController(
      text: existingJob?['district']?.toString() ?? '',
    );
    final budget = TextEditingController(
      text: existingJob?['budget'] != null
          ? existingJob!['budget'].toString()
          : '',
    );

    int? categoryId = existingJob?['category_id'] != null
        ? (existingJob!['category_id'] as num).toInt()
        : null;
    DateTime? preferredAt = existingJob?['preferred_at'] != null
        ? DateTime.tryParse(existingJob!['preferred_at'].toString())?.toLocal()
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void pickPreferredDateTime() async {
            final now = DateTime.now();
            final initial = preferredAt != null && preferredAt!.isAfter(now)
                ? preferredAt!
                : now.add(const Duration(days: 1));
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: now,
              lastDate: DateTime(2100),
            );
            if (pickedDate == null || !context.mounted) return;

            final pickedTime = await showTimePicker(
              context: context,
              initialTime: preferredAt != null
                  ? TimeOfDay.fromDateTime(preferredAt!)
                  : const TimeOfDay(hour: 9, minute: 0),
            );
            if (pickedTime == null) return;

            setDialogState(() {
              preferredAt = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            });
          }

          return AlertDialog(
            title: Text(isEdit ? 'แก้ไขประกาศงาน' : 'ประกาศหาช่าง'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'หัวข้องาน',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณาระบุหัวข้องาน'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'ประเภทช่าง',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((category) {
                          final map = category as Map;
                          return DropdownMenuItem<int>(
                            value: (map['id'] as num).toInt(),
                            child: Text(map['name_th']?.toString() ?? ''),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => categoryId = value);
                        },
                        validator: (v) =>
                            v == null ? 'กรุณาเลือกหมวดหมู่' : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pickPreferredDateTime,
                        icon: const Icon(Icons.event_available),
                        label: Text(
                          preferredAt == null
                              ? 'เลือกวันและเวลาที่ต้องการให้เข้าทำงาน'
                              : 'นัดเข้าทำ: ${_formatDateTime(preferredAt!)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: description,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียดงาน',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณาระบุรายละเอียด'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: province,
                        decoration: const InputDecoration(
                          labelText: 'จังหวัด',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณาระบุจังหวัด'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: district,
                        decoration: const InputDecoration(
                          labelText: 'อำเภอ / เขต',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: budget,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'งบประมาณ (บาท) ไม่บังคับ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;

                  if (preferredAt == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'กรุณาเลือกวันและเวลาที่ต้องการให้เข้าทำงาน',
                        ),
                      ),
                    );
                    return;
                  }

                  final amount = budget.text.trim().isEmpty
                      ? null
                      : double.tryParse(budget.text.trim());

                  if (budget.text.trim().isNotEmpty &&
                      (amount == null || amount < 0)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('กรุณาระบุงบประมาณให้ถูกต้อง'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, true);
                },
                child: Text(isEdit ? 'บันทึกการแก้ไข' : 'ลงประกาศ'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      title.dispose();
      description.dispose();
      province.dispose();
      district.dispose();
      budget.dispose();
      return;
    }

    try {
      final amount = budget.text.trim().isEmpty
          ? null
          : double.parse(budget.text.trim());

      if (isEdit) {
        await service.updateJobPost(
          jobPostId: existingJob['id'].toString(),
          title: title.text.trim(),
          description: description.text.trim(),
          categoryId: categoryId!,
          province: province.text.trim(),
          district: district.text.trim(),
          budget: amount,
          preferredAt: preferredAt,
        );
        if (!mounted) return;
        message('แก้ไขประกาศงานสำเร็จ');
      } else {
        await service.createJobPost(
          title: title.text.trim(),
          description: description.text.trim(),
          categoryId: categoryId!,
          province: province.text.trim(),
          district: district.text.trim(),
          budget: amount,
          preferredAt: preferredAt,
        );
        if (!mounted) return;
        message('ลงประกาศงานสำเร็จ');
      }
      load();
    } catch (e) {
      if (!mounted) return;
      message('บันทึกประกาศงานไม่สำเร็จ: $e');
    } finally {
      title.dispose();
      description.dispose();
      province.dispose();
      district.dispose();
      budget.dispose();
    }
  }

  void _toggleStatus(Map job) async {
    final currentStatus = job['status']?.toString() ?? 'open';
    if (currentStatus == 'assigned') {
      message('งานนี้จ้างช่างแล้ว ไม่สามารถเปลี่ยนสถานะเปิดรับ/ปิดรับได้');
      return;
    }
    final nextStatus = currentStatus == 'open' ? 'closed' : 'open';
    try {
      await service.toggleJobPostStatus(
        jobPostId: job['id'].toString(),
        nextStatus: nextStatus,
      );
      if (!mounted) return;
      message(
        nextStatus == 'open'
            ? 'เปลี่ยนเป็น "เปิดรับ" แล้ว'
            : 'เปลี่ยนเป็น "ปิดรับ" แล้ว',
      );
      load();
    } catch (e) {
      if (!mounted) return;
      message('เปลี่ยนสถานะไม่สำเร็จ: $e');
    }
  }

  void _deleteJob(Map job) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบประกาศงาน'),
        content: Text('ต้องการลบประกาศ "${job['title']}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบประกาศ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await service.deleteJobPost(job['id'].toString());
      if (!mounted) return;
      message('ลบประกาศงานเรียบร้อยแล้ว');
      load();
    } catch (e) {
      if (!mounted) return;
      message('ลบประกาศงานไม่สำเร็จ: $e');
    }
  }

  void _cancelAcceptedHire({
    required Map job,
    required Map quote,
  }) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการจ้าง & ส่งเหตุผลให้ช่าง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('งาน: ${job['title']}'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'เหตุผลที่เลิกจ้าง (ส่งกลับไปให้ช่าง)',
                hintText: 'ระบุเหตุผลที่ยกเลิกการจ้างช่างรายนี้',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ปิด'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณาระบุเหตุผลที่เลิกจ้างก่อนส่งเหตุผล'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('ยืนยันเลิกจ้าง & ส่งเหตุผล'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      reasonCtrl.dispose();
      return;
    }

    try {
      final uid = _client.auth.currentUser?.id;
      final jobId = job['id'].toString();
      final quoteId = quote['id'].toString();
      final techId = quote['technician_id']?.toString();
      final reason = reasonCtrl.text.trim();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('quotations')
          .update({'status': 'rejected'})
          .eq('id', quoteId);

      final bookings = await _client
          .from('bookings')
          .select('id, technician_id')
          .eq('job_post_id', jobId)
          .inFilter('status', ['pending', 'accepted', 'in_progress']);

      for (final item in List.from(bookings)) {
        final bMap = item as Map;
        final bId = bMap['id']?.toString();
        if (bId != null && bId.isNotEmpty) {
          await _client.from('bookings').update({
            'status': 'cancelled',
            'cancelled_at': nowIso,
            'cancelled_by': uid,
            'cancellation_reason': reason,
          }).eq('id', bId);
        }
      }

      if (uid != null && techId != null && techId.isNotEmpty) {
        await _client.from('job_cancellation_feedbacks').insert({
          'job_post_id': jobId,
          'quotation_id': quoteId,
          'customer_id': uid,
          'technician_id': techId,
          'reason': reason,
        });
      }

      await _client
          .from('job_posts')
          .update({'status': 'open'})
          .eq('id', jobId);

      if (!mounted) return;
      message('ยกเลิกการจ้างและส่งเหตุผลให้ช่างเรียบร้อยแล้ว');
      load();
    } catch (e) {
      if (!mounted) return;
      message('ยกเลิกการจ้างไม่สำเร็จ: $e');
    } finally {
      reasonCtrl.dispose();
    }
  }

  void showQuotations(Map job) async {
    try {
      final quotations = List<dynamic>.from(
        await service.getJobQuotations(job['id'].toString()) as List,
      );
      final profilesById = _loadTechnicianProfiles(quotations);

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            _syncTechnicianProfilesFromDb(
              quotations,
              profilesById,
              () => setSheetState(() {}),
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  height: MediaQuery.of(sheetContext).size.height * 0.65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ใบเสนอราคา: ${job['title']}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: quotations.isEmpty
                            ? const Center(
                                child: Text('ยังไม่มีช่างส่งใบเสนอราคา'),
                              )
                            : ListView.builder(
                                itemCount: quotations.length,
                                itemBuilder: (_, index) {
                                  final quote = quotations[index] as Map;
                                  final status =
                                      quote['status']?.toString() ?? 'pending';
                                  final phone = quote['technician_phone'] ??
                                      quote['phone'] ??
                                      '-';

                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            title: _technicianAvatarAndName(
                                              quote: quote,
                                              profilesById: profilesById,
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                'โทร: $phone\n${quote['terms'] ?? 'ไม่มีรายละเอียดเพิ่มเติม'}\nสถานะ: $status',
                                              ),
                                            ),
                                            isThreeLine: true,
                                            trailing: Text(
                                              '${quote['price']} ฿',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                              ),
                                            ),
                                            onTap: status == 'pending' &&
                                                    job['status'] == 'open'
                                                ? () {
                                                    showDialog<bool>(
                                                      context: sheetContext,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                          'ยืนยันจ้างช่างรายนี้?',
                                                        ),
                                                        content: const Text(
                                                          'เมื่อยืนยันแล้วจะสร้างรายการจองพร้อม Job Number และปิดรับใบเสนอราคาอื่น',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              'ยกเลิก',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              'ยืนยันจ้าง',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ).then((confirm) async {
                                                      if (confirm != true) return;
                                                      if (!mounted ||
                                                          !sheetContext
                                                              .mounted) {
                                                        return;
                                                      }

                                                      try {
                                                        final createdBooking =
                                                            await service
                                                                .acceptQuotation(
                                                          quotationId:
                                                              quote['id']
                                                                  .toString(),
                                                          jobPostId:
                                                              job['id']
                                                                  .toString(),
                                                        );

                                                        if (!mounted ||
                                                            !sheetContext
                                                                .mounted) {
                                                          return;
                                                        }
                                                        Navigator.pop(
                                                          sheetContext,
                                                        );
                                                        final jobNo =
                                                            createdBooking[
                                                                'job_number'];
                                                        message(
                                                          jobNo != null
                                                              ? 'ยืนยันจ้างสำเร็จ (Job: $jobNo)'
                                                              : 'ยืนยันจ้างสำเร็จ',
                                                        );
                                                        load();
                                                      } catch (e) {
                                                        if (!mounted) return;
                                                        message(
                                                          'ดำเนินการไม่สำเร็จ: $e',
                                                        );
                                                      }
                                                    });
                                                  }
                                                : null,
                                          ),
                                          if (status == 'accepted')
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(sheetContext);
                                                    _cancelAcceptedHire(
                                                      job: job,
                                                      quote: quote,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.feedback_outlined,
                                                  ),
                                                  label: const Text(
                                                    'ยกเลิกการจ้าง & ส่งเหตุผลให้ช่าง',
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      message('โหลดใบเสนอราคาไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('ประกาศงานของฉัน'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openJobForm(),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ประกาศหาช่าง'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => load(),
              child: jobs.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('ยังไม่มีประกาศงาน')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length,
                      itemBuilder: (_, index) {
                        final job = jobs[index] as Map;
                        final category = job['service_categories'] as Map?;
                        final preferredParsed = job['preferred_at'] != null
                            ? DateTime.tryParse(job['preferred_at'].toString())
                            : null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        job['title']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    _buildStatusBadge(job),
                                    IconButton(
                                      tooltip: 'แก้ไขประกาศ',
                                      onPressed: () =>
                                          _openJobForm(existingJob: job),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'ลบประกาศ',
                                      onPressed: () => _deleteJob(job),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                Text(
                                  category?['name_th']?.toString() ??
                                      'ไม่ระบุหมวดหมู่',
                                  style: const TextStyle(color: primary),
                                ),
                                const SizedBox(height: 8),
                                Text(job['description']?.toString() ?? ''),
                                const SizedBox(height: 8),
                                Text(
                                  '${job['district'] ?? ''} ${job['province'] ?? ''}',
                                ),
                                if (preferredParsed != null)
                                  Text(
                                    'วันเวลาที่ต้องการ: ${_formatDateTime(preferredParsed)}',
                                  ),
                                Text(
                                  'งบประมาณ: ${job['budget'] ?? 'ไม่ระบุ'} บาท',
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => showQuotations(job),
                                    icon: const Icon(Icons.request_quote),
                                    label: const Text('ดูใบเสนอราคา'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}