import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer_bookings_screen.dart';

class _ServiceCategoryOption {
  final String key;
  final String label;
  final IconData icon;
  final keywords;

  const _ServiceCategoryOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.keywords,
  });
}

class CustomerFindTechnicianScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const CustomerFindTechnicianScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  @override
  State<CustomerFindTechnicianScreen> createState() =>
      _CustomerFindTechnicianScreenState();
}

class _CustomerFindTechnicianScreenState
    extends State<CustomerFindTechnicianScreen> {
  static const Color primary = Color(0xFF7041D8);

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _loading = true;
  String _selectedCategory = 'all';
  var _offers = [];
  var _profilesById = {};

  static const _categories = [
    _ServiceCategoryOption(
      key: 'all',
      label: 'ทั้งหมด',
      icon: Icons.apps,
      keywords: [],
    ),
    _ServiceCategoryOption(
      key: 'ช่างไฟฟ้า',
      label: 'ช่างไฟฟ้า',
      icon: Icons.electrical_services,
      keywords: ['ไฟฟ้า', 'ไฟ', 'เดินสาย', 'เบรกเกอร์', 'ปลั๊ก'],
    ),
    _ServiceCategoryOption(
      key: 'ช่างประปา',
      label: 'ช่างประปา',
      icon: Icons.water_drop_outlined,
      keywords: ['ประปา', 'ท่อ', 'ก๊อก', 'ปั๊มน้ำ', 'รั่ว'],
    ),
    _ServiceCategoryOption(
      key: 'ช่างแอร์',
      label: 'ช่างแอร์',
      icon: Icons.ac_unit,
      keywords: ['แอร์', 'ปรับอากาศ', 'ล้างแอร์', 'เติมน้ำยา'],
    ),
    _ServiceCategoryOption(
      key: 'ช่างซ่อมบ้าน',
      label: 'ช่างซ่อมบ้าน',
      icon: Icons.home_repair_service,
      keywords: ['ซ่อมบ้าน', 'ต่อเติม', 'ปูน', 'สี', 'หลังคา', 'ประตู'],
    ),
    _ServiceCategoryOption(
      key: 'กล้องวงจรปิด',
      label: 'กล้องวงจรปิด',
      icon: Icons.camera_alt_outlined,
      keywords: ['กล้องวงจรปิด', 'กล้อง', 'cctv'],
    ),
    _ServiceCategoryOption(
      key: 'แม่บ้าน',
      label: 'แม่บ้าน',
      icon: Icons.cleaning_services,
      keywords: ['แม่บ้าน', 'ทำความสะอาด', 'กวาด', 'ถู'],
    ),
    _ServiceCategoryOption(
      key: 'กระจกอลูมิเนียม',
      label: 'กระจกอลูมิเนียม',
      icon: Icons.window_outlined,
      keywords: [
        'กระจกอลูมิเนียม',
        'กระจก',
        'อลูมิเนียม',
        'หน้าต่าง',
        'บานเลื่อน',
      ],
    ),
    _ServiceCategoryOption(
      key: 'รางน้ำ',
      label: 'รางน้ำ',
      icon: Icons.water_damage_outlined,
      keywords: ['รางน้ำ', 'รางน้ำฝน'],
    ),
    _ServiceCategoryOption(
      key: 'สระว่ายน้ำ',
      label: 'สระว่ายน้ำ',
      icon: Icons.pool_outlined,
      keywords: ['สระว่ายน้ำ', 'สระ'],
    ),
  ];

  @override
  void initState() {
    super.initState();

    final initCat = (widget.initialCategory ?? '').trim();
    final initQ = (widget.initialQuery ?? '').trim();

    if (initCat.isNotEmpty) {
      _selectedCategory = _matchCategoryKey(initCat) ?? 'all';
    } else if (initQ.isNotEmpty) {
      final matched = _matchCategoryKey(initQ);
      if (matched != null) {
        _selectedCategory = matched;
      } else {
        _searchController.text = initQ;
      }
    }

    _loadOffers();
  }

  String? _matchCategoryKey(String input) {
    final lower = input.toLowerCase();
    for (final cat in _categories) {
      if (cat.key == 'all') continue;
      final kws = cat.keywords as List;
      if (cat.key.toLowerCase() == lower ||
          cat.label.toLowerCase() == lower ||
          kws.any((k) => lower.contains(k.toString().toLowerCase()))) {
        return cat.key;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _extractTechnicianId(Map row) {
    for (final key in const [
      'technician_id',
      'user_id',
      'provider_id',
      'owner_id',
    ]) {
      final raw = row[key]?.toString().trim() ?? '';
      if (raw.isNotEmpty) return raw;
    }
    return null;
  }

  void _loadOffers() async {
    setState(() => _loading = true);
    try {
      var rawRows = [];
      for (final tableName in const [
        'technician_service_prices',
        'technician_pricing',
        'service_prices',
      ]) {
        try {
          final rows = await _client.from(tableName).select('*');
          rawRows = List.from(rows);
          if (rawRows.isNotEmpty) break;
        } catch (_) {}
      }

      final activeTechIdsWithBooking = <String>{};
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        try {
          final bookedRows = await _client
              .from('bookings')
              .select('technician_id, status')
              .eq('customer_id', uid);
          for (final b in List.from(bookedRows)) {
            if (b is Map) {
              final st = b['status']?.toString() ?? '';
              if (st == 'cancelled' || st == 'rejected') continue;
              final tid = b['technician_id']?.toString().trim() ?? '';
              if (tid.isNotEmpty) activeTechIdsWithBooking.add(tid);
            }
          }
        } catch (_) {}
      }

      final normalized = [];
      final techIds = <String>{};

      for (final item in rawRows) {
        if (item is! Map) continue;
        final map = Map.from(item);

        final isActiveRaw = map['is_active'];
        if (isActiveRaw is bool && !isActiveRaw) continue;

        final tid = _extractTechnicianId(map) ?? '';
        if (tid.isNotEmpty) {
          if (activeTechIdsWithBooking.contains(tid)) continue;
          map['_tech_id'] = tid;
          techIds.add(tid);
        }
        normalized.add(map);
      }

      final profilesMap = {};
      if (techIds.isNotEmpty) {
        try {
          final pRows = await _client
              .from('profiles')
              .select('id, full_name, avatar_url, phone')
              .inFilter('id', techIds.toList());
          for (final p in List.from(pRows)) {
            if (p is Map) {
              final pid = p['id']?.toString().trim() ?? '';
              if (pid.isNotEmpty) {
                profilesMap[pid] = Map.from(p);
              }
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _offers = normalized;
        _profilesById = profilesMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMsg('โหลดรายการบริการช่างไม่สำเร็จ: $e');
    }
  }

  String _formatOfferPrice(Map offer) {
    final priceType = offer['price_type']?.toString() ?? 'fixed';
    final minVal = (offer['min_price'] as num?)?.toDouble() ??
        (offer['price'] as num?)?.toDouble() ??
        0;
    final maxVal = (offer['max_price'] as num?)?.toDouble();

    switch (priceType) {
      case 'starting':
        return 'เริ่มต้น ${minVal.toStringAsFixed(0)} บาท';
      case 'range':
        return '${minVal.toStringAsFixed(0)} - ${maxVal != null ? maxVal.toStringAsFixed(0) : '-'} บาท';
      case 'fixed':
      default:
        return '${minVal.toStringAsFixed(0)} บาท';
    }
  }

  List get _filteredOffers {
    final query = _searchController.text.trim().toLowerCase();
    final selectedOpt = _categories.firstWhere(
      (c) => c.key == _selectedCategory,
      orElse: () => _categories.first,
    );

    return _offers.where((offerItem) {
      final offer = offerItem as Map;
      final tid = offer['_tech_id']?.toString() ?? '';
      final profile = tid.isNotEmpty ? _profilesById[tid] as Map? : null;
      final techName =
          (profile?['full_name']?.toString() ?? '').toLowerCase();
      final serviceName =
          (offer['name_th']?.toString() ?? offer['title']?.toString() ?? '')
              .toLowerCase();
      final serviceEn = (offer['name_en']?.toString() ?? '').toLowerCase();
      final desc = (offer['description_th']?.toString() ??
              offer['description']?.toString() ??
              '')
          .toLowerCase();
      final categoryName = (offer['category_name']?.toString() ??
              offer['category']?.toString() ??
              '')
          .toLowerCase();

      final combinedText = '$serviceName $serviceEn $desc $categoryName';

      if (selectedOpt.key != 'all') {
        final kws = selectedOpt.keywords as List;
        final matchedCategory = kws.any(
          (kw) => combinedText.contains(kw.toString().toLowerCase()),
        );
        if (!matchedCategory) return false;
      }

      if (query.isEmpty) return true;
      return techName.contains(query) || combinedText.contains(query);
    }).toList();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} เวลา $hh:$mm น.';
  }

  void _hireTechnician(Map offer) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _showMsg('กรุณาเข้าสู่ระบบก่อนเลือกจ้างช่าง');
      return;
    }

    final tid = offer['_tech_id']?.toString().trim() ?? '';
    if (tid.isEmpty) {
      _showMsg('ไม่พบข้อมูลบัญชีช่างสำหรับรายการนี้');
      return;
    }

    final techProfile = _profilesById[tid] as Map?;
    final techName =
        techProfile?['full_name']?.toString().trim().isNotEmpty == true
            ? techProfile!['full_name'].toString().trim()
            : 'ช่างผู้ให้บริการ';
    final techAvatarUrl = techProfile?['avatar_url']?.toString().trim() ?? '';
    final hasTechAvatar = techAvatarUrl.isNotEmpty;

    final serviceTitle =
        offer['name_th']?.toString().trim().isNotEmpty == true
            ? offer['name_th'].toString().trim()
            : (offer['title']?.toString().trim() ?? 'งานบริการ');
    final priceLabel = _formatOfferPrice(offer);

    DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
    scheduledAt = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
      9,
      0,
    );

    final addressCtrl = TextEditingController();
    final descCtrl = TextEditingController(
      text: '$serviceTitle ($priceLabel)',
    );
    final phoneCtrl = TextEditingController();

    try {
      final custRow = await _client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();
      if (custRow != null && phoneCtrl.text.trim().isEmpty) {
        phoneCtrl.text = custRow['phone']?.toString() ?? '';
      }
    } catch (_) {}

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          void pickSchedule() async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: scheduledAt,
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
            );
            if (pickedDate == null || !context.mounted) return;

            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(scheduledAt),
            );
            if (pickedTime == null) return;

            setDialogState(() {
              scheduledAt = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            });
          }

          return AlertDialog(
            title: const Text('จ้างช่าง (สถานะ: รอช่างตอบรับ)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEDE7FF),
                        backgroundImage:
                            hasTechAvatar ? NetworkImage(techAvatarUrl) : null,
                        child: !hasTechAvatar
                            ? const Icon(Icons.engineering, color: primary)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              techName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$serviceTitle • $priceLabel',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: pickSchedule,
                    icon: const Icon(Icons.event),
                    label: Text('นัดหมาย: ${_formatDateTime(scheduledAt)}'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'เบอร์โทรศัพท์ติดต่อ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ที่อยู่หน้างาน / สถานที่ให้บริการ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'รายละเอียดงานที่ต้องการให้ทำ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (addressCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('กรุณาระบุที่อยู่หน้างาน'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx, true);
                },
                icon: const Icon(Icons.send),
                label: const Text('ยืนยันจ้าง (รอช่างตอบรับ)'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) {
      addressCtrl.dispose();
      descCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }

    try {
      String customerName =
          user.userMetadata?['full_name']?.toString().trim() ?? '';
      String customerPhone = phoneCtrl.text.trim();
      try {
        final custProfile = await _client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', user.id)
            .maybeSingle();
        if (custProfile != null) {
          final pName = custProfile['full_name']?.toString().trim() ?? '';
          if (pName.isNotEmpty) customerName = pName;
          if (customerPhone.isEmpty) {
            customerPhone = custProfile['phone']?.toString().trim() ?? '';
          }
        }
      } catch (_) {}

      final jobNumber =
          'JOB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final rawDesc = descCtrl.text.trim();
      final fullDesc =
          rawDesc.contains('บาท') ? rawDesc : '$rawDesc ($priceLabel)';

      await _client.from('bookings').insert({
        'job_number': jobNumber,
        'customer_id': user.id,
        'technician_id': tid,
        'customer_name':
            customerName.isNotEmpty ? customerName : (user.email ?? 'ลูกค้า'),
        'customer_phone': customerPhone.isEmpty ? null : customerPhone,
        'service_address': addressCtrl.text.trim(),
        'description': fullDesc,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() {
        _offers = _offers.where((item) => !identical(item, offer)).toList();
      });
      _showMsg('ส่งคำขอจ้างแล้ว ($jobNumber) • สถานะ: รอช่างตอบรับ');

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerBookingsScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      _showMsg('ส่งคำขอจ้างไม่สำเร็จ: $e');
    } finally {
      addressCtrl.dispose();
      descCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredOffers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('ค้นหาช่างและบริการ'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'การจองของฉัน',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerBookingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(onPressed: _loadOffers, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อช่าง หรือบริการ เช่น ล้างแอร์, เดินสายไฟ',
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              key: ValueKey(_selectedCategory),
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'หมวดหมู่ช่าง',
                prefixIcon: const Icon(Icons.category_outlined, color: primary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.key,
                  child: Row(
                    children: [
                      Icon(cat.icon, size: 18, color: primary),
                      const SizedBox(width: 8),
                      Text(cat.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.key;
                return ChoiceChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: isSelected ? Colors.white : primary,
                  ),
                  label: Text(cat.label),
                  selected: isSelected,
                  selectedColor: primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat.key),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          _selectedCategory == 'all'
                              ? 'ยังไม่มีรายการบริการจากช่างที่เปิดให้บริการ'
                              : 'ไม่พบช่างในหมวดหมู่ "$_selectedCategory"',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _loadOffers(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final offer = items[index] as Map;
                            final tid = offer['_tech_id']?.toString() ?? '';
                            final profile = tid.isNotEmpty
                                ? _profilesById[tid] as Map?
                                : null;
                            final techName = profile?['full_name']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? profile!['full_name'].toString().trim()
                                : 'ช่างผู้ให้บริการ';
                            final avatarUrl =
                                profile?['avatar_url']?.toString().trim() ?? '';
                            final hasAvatar = avatarUrl.isNotEmpty;
                            final serviceName = offer['name_th']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? offer['name_th'].toString().trim()
                                : (offer['title']?.toString().trim() ??
                                    'งานบริการ');
                            final desc = offer['description_th']
                                    ?.toString()
                                    .trim() ??
                                offer['description']?.toString().trim() ??
                                '';
                            final priceText = _formatOfferPrice(offer);

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
                                          backgroundColor:
                                              const Color(0xFFEDE7FF),
                                          backgroundImage: hasAvatar
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: !hasAvatar
                                              ? const Icon(
                                                  Icons.engineering,
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
                                                techName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                serviceName,
                                                style: const TextStyle(
                                                  color: primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          priceText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(desc),
                                    ],
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _hireTechnician(offer),
                                        icon: const Icon(Icons.handyman),
                                        label: const Text(
                                          'จ้างช่าง (รอช่างตอบรับ)',
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
          ),
        ],
      ),
    );
  }
}