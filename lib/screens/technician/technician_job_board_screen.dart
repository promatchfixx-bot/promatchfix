import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/job_board_service.dart';

class TechnicianJobBoardScreen extends StatefulWidget {
  const TechnicianJobBoardScreen({super.key});

  @override
  State<TechnicianJobBoardScreen> createState() =>
      _TechnicianJobBoardScreenState();
}

class _TechnicianJobBoardScreenState extends State<TechnicianJobBoardScreen> {
  final service = JobBoardService();
  final _client = Supabase.instance.client;

  var jobs = [];
  var categories = [];
  var myQuotations = [];
  var cancellationFeedbacks = [];
  Map<String, Map<String, dynamic>> customerProfilesById = {};

  String defaultTechnicianName = '';
  String defaultTechnicianPhone = '';
  int? categoryId;
  String province = '';
  String district = '';

  bool loading = true;
  bool kycVerified = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  void message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String? _extractCustomerId(Map job) {
    for (final key in const ['customer_id', 'user_id', 'created_by']) {
      final val = job[key]?.toString().trim() ?? '';
      if (val.isNotEmpty) return val;
    }
    final nestedProfile = job['profiles'];
    if (nestedProfile is Map) {
      final id = nestedProfile['id']?.toString().trim() ?? '';
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  Future<void> _loadCustomerProfiles(List openJobs) async {
    final map = <String, Map<String, dynamic>>{};
    final ids = <String>{};

    for (final item in openJobs) {
      if (item is! Map) continue;
      final nestedProfile = item['profiles'];
      final cid = _extractCustomerId(item);
      if (cid != null) ids.add(cid);

      if (nestedProfile is Map && cid != null) {
        map[cid] = Map<String, dynamic>.from(nestedProfile);
      }
    }

    if (ids.isNotEmpty) {
      try {
        final rows = await _client
            .from('profiles')
            .select('id, full_name, avatar_url, phone')
            .inFilter('id', ids.toList());

        for (final row in List.from(rows)) {
          if (row is Map) {
            final pid = row['id']?.toString().trim() ?? '';
            if (pid.isNotEmpty) {
              map[pid] = {
                ...?map[pid],
                ...Map<String, dynamic>.from(row),
              };
            }
          }
        }
      } catch (_) {}
    }

    customerProfilesById = map;
  }

  Widget _buildCustomerHeader(Map job) {
    final cid = _extractCustomerId(job);
    final profile = cid != null ? customerProfilesById[cid] : null;
    final nested = job['profiles'] is Map ? job['profiles'] as Map : null;

    final rawName = profile?['full_name']?.toString().trim() ??
        nested?['full_name']?.toString().trim() ??
        job['customer_name']?.toString().trim() ??
        '';
    final displayName = rawName.isNotEmpty ? rawName : 'ลูกค้าทั่วไป';

    final rawAvatar = profile?['avatar_url']?.toString().trim() ??
        nested?['avatar_url']?.toString().trim() ??
        job['customer_avatar_url']?.toString().trim() ??
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
                  Icons.person,
                  size: 18,
                  color: Color(0xFF7041D8),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'ผู้ประกาศจ้างงาน',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final verified = await service.isTechnicianKycVerified();
      final defaults = await service.getMyTechnicianDefaults();
      final allCategories = await service.getCategories();
      final openJobs = await service.getOpenJobPosts(
        categoryId: categoryId,
        province: province,
        district: district,
      );
      final quotes = await service.getMyQuotations();
      final feedbacks = await service.getMyCancellationFeedbacks();

      await _loadCustomerProfiles(List.from(openJobs));

      if (!mounted) return;

      final defMap = defaults as Map;
      setState(() {
        kycVerified = verified == true;
        defaultTechnicianName = defMap['name']?.toString() ?? '';
        defaultTechnicianPhone = defMap['phone']?.toString() ?? '';
        categories = List.from(allCategories);
        jobs = List.from(openJobs);
        myQuotations = List.from(quotes);
        cancellationFeedbacks = List.from(feedbacks);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      message('โหลดบอร์ดงานไม่สำเร็จ: $e');
    }
  }

  Map? findMyQuotationForJob(String jobId) {
    for (final item in myQuotations) {
      final q = item as Map;
      if (q['job_post_id']?.toString() == jobId) {
        return q;
      }
    }
    return null;
  }

  Future<void> submitQuote(Map job) async {
    if (!kycVerified) {
      message('กรุณายืนยันตัวตน KYC ให้ผ่านก่อนจึงจะส่งใบเสนอราคาได้');
      return;
    }

    final techName = TextEditingController(text: defaultTechnicianName);
    final price = TextEditingController();
    final phone = TextEditingController(text: defaultTechnicianPhone);
    final terms = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ส่งใบเสนอราคา'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('งาน: ${job['title']}'),
              const SizedBox(height: 16),
              TextField(
                controller: techName,
                decoration: const InputDecoration(
                  labelText: 'ชื่อช่าง',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ราคาเสนอ (บาท)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์ช่าง',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: terms,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียดและเงื่อนไข',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final cleanName = techName.text.trim();
              final amount = double.tryParse(price.text.trim());
              final cleanPhone = phone.text.trim();

              if (cleanName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุชื่อช่าง')),
                );
                return;
              }

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุราคาที่ถูกต้อง')),
                );
                return;
              }

              if (cleanPhone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุเบอร์โทรศัพท์ช่าง')),
                );
                return;
              }

              Navigator.pop(dialogContext, true);
            },
            child: const Text('ส่งราคา'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      techName.dispose();
      price.dispose();
      phone.dispose();
      terms.dispose();
      return;
    }

    try {
      await service.submitQuotation(
        jobPostId: job['id'].toString(),
        technicianName: techName.text.trim(),
        price: double.parse(price.text.trim()),
        phone: phone.text.trim(),
        terms: terms.text.trim(),
      );

      if (!mounted) return;

      message('ส่งใบเสนอราคาสำเร็จ');
      await load();
    } catch (e) {
      message('ส่งใบเสนอราคาไม่สำเร็จ: $e');
    } finally {
      techName.dispose();
      price.dispose();
      phone.dispose();
      terms.dispose();
    }
  }

  Future<void> _editQuote(Map quote) async {
    final techName = TextEditingController(
      text: quote['technician_name']?.toString() ?? defaultTechnicianName,
    );
    final price = TextEditingController(text: quote['price']?.toString() ?? '');
    final phone = TextEditingController(
      text: quote['technician_phone']?.toString() ?? defaultTechnicianPhone,
    );
    final terms = TextEditingController(text: quote['terms']?.toString() ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('แก้ไขใบเสนอราคา'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: techName,
                decoration: const InputDecoration(
                  labelText: 'ชื่อช่าง',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'ราคาเสนอ (บาท)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทรศัพท์ช่าง',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: terms,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'รายละเอียดและเงื่อนไข',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(price.text.trim());
              if (techName.text.trim().isEmpty ||
                  amount == null ||
                  amount <= 0 ||
                  phone.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณาระบุชื่อช่าง ราคา และเบอร์โทรให้ถูกต้อง'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      techName.dispose();
      price.dispose();
      phone.dispose();
      terms.dispose();
      return;
    }

    try {
      await service.updateQuotation(
        quotationId: quote['id'].toString(),
        technicianName: techName.text.trim(),
        price: double.parse(price.text.trim()),
        phone: phone.text.trim(),
        terms: terms.text.trim(),
      );
      if (!mounted) return;
      message('แก้ไขใบเสนอราคาสำเร็จ');
      await load();
    } catch (e) {
      if (!mounted) return;
      message('แก้ไขใบเสนอราคาไม่สำเร็จ: $e');
    } finally {
      techName.dispose();
      price.dispose();
      phone.dispose();
      terms.dispose();
    }
  }

  Future<void> _cancelQuote(Map quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการส่งใบเสนอราคา'),
        content: const Text('ต้องการยกเลิกใบเสนอราคานี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await service.cancelQuotation(quote['id'].toString());
      if (!mounted) return;
      message('ยกเลิกใบเสนอราคาแล้ว');
      await load();
    } catch (e) {
      if (!mounted) return;
      message('ยกเลิกใบเสนอราคาไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('บอร์ดประกาศงาน'),
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
                  if (!kycVerified)
                    Card(
                      color: Colors.amber.shade50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'บัญชีช่างยังไม่ผ่านการยืนยันตัวตน KYC จึงยังไม่สามารถส่งใบเสนอราคาได้',
                        ),
                      ),
                    ),
                  if (cancellationFeedbacks.isNotEmpty) ...[
                    Card(
                      color: Colors.red.shade50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'แจ้งเตือนงานที่ลูกค้ายกเลิกจ้าง',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...cancellationFeedbacks.take(3).map((item) {
                              final fb = item as Map;
                              final jobMap = fb['job_posts'] as Map?;
                              final title =
                                  jobMap?['title']?.toString() ?? 'ประกาศงาน';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• $title: ${fb['reason'] ?? '-'}',
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Text(
                    'ค้นหางานที่ต้องการรับ',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'หมวดหมู่งานทั้งหมด',
                      filled: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('ทุกหมวดหมู่'),
                      ),
                      ...categories.map((item) {
                        final map = item as Map;
                        return DropdownMenuItem<int>(
                          value: (map['id'] as num).toInt(),
                          child: Text(map['name_th']?.toString() ?? ''),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => categoryId = value);
                      load();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'จังหวัด',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    onChanged: (value) => province = value,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'อำเภอ / เขต',
                      prefixIcon: Icon(Icons.place_outlined),
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    onChanged: (value) => district = value,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหางาน'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'งานที่เปิดรับ (${jobs.length})',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('ยังไม่มีประกาศงานในพื้นที่นี้'),
                      ),
                    ),
                  ...jobs.map((item) {
                    final job = item as Map;
                    final id = job['id'].toString();
                    final category = job['service_categories'] as Map?;
                    final existingQuote = findMyQuotationForJob(id);
                    final isPendingQuote = existingQuote != null &&
                        (existingQuote['status']?.toString() ?? 'pending') ==
                            'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCustomerHeader(job),
                            const Divider(height: 20),
                            Text(
                              job['title']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Chip(
                              label: Text(
                                category?['name_th']?.toString() ?? 'งานทั่วไป',
                              ),
                            ),
                            Text(job['description']?.toString() ?? ''),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${job['district'] ?? ''} ${job['province'] ?? ''}',
                                  ),
                                ),
                              ],
                            ),
                            if (job['preferred_at'] != null) ...[
                              const SizedBox(height: 6),
                              Text('วันเวลาที่ต้องการ: ${job['preferred_at']}'),
                            ],
                            const SizedBox(height: 6),
                            Text('งบประมาณ: ${job['budget'] ?? 'ไม่ระบุ'} บาท'),
                            const SizedBox(height: 14),
                            if (isPendingQuote) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'เสนอราคาแล้ว: ${existingQuote['price']} บาท • ช่าง ${existingQuote['technician_name'] ?? defaultTechnicianName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _editQuote(existingQuote),
                                      icon: const Icon(Icons.edit_outlined),
                                      label: const Text('แก้ไขราคา'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _cancelQuote(existingQuote),
                                      icon: const Icon(Icons.close),
                                      label: const Text('ยกเลิกส่ง'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: kycVerified
                                      ? () => submitQuote(job)
                                      : () => message(
                                            'กรุณายืนยันตัวตน KYC ให้ผ่านก่อนส่งใบเสนอราคา',
                                          ),
                                  icon: Icon(
                                    !kycVerified
                                        ? Icons.lock_outline
                                        : Icons.send,
                                  ),
                                  label: Text(
                                    !kycVerified
                                        ? 'ต้องผ่าน KYC ก่อนเสนอราคา'
                                        : 'ส่งใบเสนอราคา',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Text(
                    'ใบเสนอราคาของฉัน',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  ...myQuotations.map((item) {
                    final quote = item as Map;
                    final job = quote['job_posts'] as Map?;
                    final isPending =
                        (quote['status']?.toString() ?? 'pending') == 'pending';
                    final techDisplay =
                        quote['technician_name']?.toString().trim().isNotEmpty ==
                                true
                            ? quote['technician_name'].toString()
                            : defaultTechnicianName;

                    return Card(
                      child: ListTile(
                        title: Text(
                          job?['title']?.toString() ?? 'งานที่ประกาศ',
                        ),
                        subtitle: Text(
                          'ช่าง: ${techDisplay.isEmpty ? '-' : techDisplay}\nราคา ${quote['price']} บาท • โทร ${quote['technician_phone'] ?? '-'}\nสถานะ ${quote['status']}',
                        ),
                        isThreeLine: true,
                        trailing: isPending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'แก้ไขใบเสนอราคา',
                                    onPressed: () => _editQuote(quote),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'ยกเลิกใบเสนอราคา',
                                    onPressed: () => _cancelQuote(quote),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              )
                            : const Icon(Icons.receipt_long),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}