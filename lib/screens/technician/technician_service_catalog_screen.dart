import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/technician_service_price_model.dart';
import '../../services/technician_pricing_service.dart';
import 'technician_jobs_screen.dart';

class TechnicianServiceCatalogScreen extends StatefulWidget {
  const TechnicianServiceCatalogScreen({super.key});

  @override
  State<TechnicianServiceCatalogScreen> createState() =>
      _TechnicianServiceCatalogScreenState();
}

class _TechnicianServiceCatalogScreenState
    extends State<TechnicianServiceCatalogScreen> {
  static const Color primary = Color(0xFF7041D8);

  static const List<String> _categoryOptions = [
    'ช่างไฟฟ้า',
    'ช่างประปา',
    'ช่างแอร์',
    'ช่างซ่อมบ้าน',
    'กล้องวงจรปิด',
    'แม่บ้าน',
    'กระจกอลูมิเนียม',
    'รางน้ำ',
    'สระว่ายน้ำ',
  ];

  final TechnicianPricingService _service = TechnicianPricingService();
  final _client = Supabase.instance.client;

  var _prices = [];
  bool _loading = true;
  String _techName = 'ช่างผู้ให้บริการ';
  String _techAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadTechnicianProfile();
    _loadPrices();
  }

  void _loadTechnicianProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    String name = user.userMetadata?['full_name']?.toString().trim() ?? '';
    String avatar = user.userMetadata?['avatar_url']?.toString().trim() ?? '';

    try {
      final row = await _client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        final dbName = row['full_name']?.toString().trim() ?? '';
        final dbAvatar = row['avatar_url']?.toString().trim() ?? '';
        if (dbName.isNotEmpty) name = dbName;
        if (dbAvatar.isNotEmpty) avatar = dbAvatar;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _techName = name.isNotEmpty ? name : (user.email ?? 'ช่างผู้ให้บริการ');
      _techAvatarUrl = avatar;
    });
  }

  void _loadPrices() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final items = await _service.getMyPrices();
      if (!mounted) return;
      setState(() {
        _prices = List.from(items);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('โหลดข้อมูลไม่สำเร็จ: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _detectCategory(TechnicianServicePrice item) {
    final combined =
        '${item.nameTh} ${item.nameEn} ${item.descriptionTh}'.toLowerCase();
    for (final cat in _categoryOptions) {
      final shortKey = cat.replaceFirst('ช่าง', '').toLowerCase();
      if (combined.contains(cat.toLowerCase()) ||
          (shortKey.isNotEmpty && combined.contains(shortKey))) {
        return cat;
      }
    }
    return _categoryOptions.first;
  }

  String _formatPrice(TechnicianServicePrice item) {
    switch (item.priceType) {
      case 'starting':
        return 'เริ่มต้น ${item.minPrice.toStringAsFixed(0)} บาท';
      case 'range':
        final maxText = item.maxPrice != null
            ? item.maxPrice!.toStringAsFixed(0)
            : '-';
        return '${item.minPrice.toStringAsFixed(0)} - $maxText บาท';
      case 'fixed':
      default:
        return '${item.minPrice.toStringAsFixed(0)} บาท';
    }
  }

  void _confirmDelete(TechnicianServicePrice item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ยืนยันการลบบริการ'),
        content: Text('ต้องการลบ "${item.nameTh}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deletePrice(item.id);
      if (!mounted) return;
      _loadPrices();
      _message('ลบบริการเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      _message('ลบไม่สำเร็จ: $e');
    }
  }

  void _openForm({TechnicianServicePrice? item}) async {
    final nameTh = TextEditingController(text: item?.nameTh ?? '');
    final nameEn = TextEditingController(text: item?.nameEn ?? '');
    final min = TextEditingController(
      text: item != null ? item.minPrice.toStringAsFixed(0) : '',
    );
    final max = TextEditingController(
      text: item?.maxPrice != null ? item!.maxPrice!.toStringAsFixed(0) : '',
    );
    final description = TextEditingController(text: item?.descriptionTh ?? '');

    String selectedCategory =
        item != null ? _detectCategory(item) : _categoryOptions.first;
    String priceType = item?.priceType ?? 'fixed';
    bool active = item?.isActive ?? true;
    bool savingSheet = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, refresh) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item == null ? 'เพิ่มบริการใหม่' : 'แก้ไขบริการ',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      key: ValueKey('cat_$selectedCategory'),
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'หมวดหมู่ช่าง (ใช้กรองหน้าค้นหาช่าง)',
                        border: OutlineInputBorder(),
                      ),
                      items: _categoryOptions
                          .map(
                            (cat) => DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          refresh(() => selectedCategory = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameTh,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อบริการ (ภาษาไทย)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameEn,
                      decoration: const InputDecoration(
                        labelText: 'Service Name (English)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียดบริการ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'รูปแบบราคา',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('pt_$priceType'),
                      initialValue: priceType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('ราคาคงที่'),
                        ),
                        DropdownMenuItem(
                          value: 'starting',
                          child: Text('ราคาเริ่มต้น'),
                        ),
                        DropdownMenuItem(
                          value: 'range',
                          child: Text('ช่วงราคา'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          refresh(() => priceType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: min,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ราคาต่ำสุด / ราคา',
                        suffixText: 'บาท',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (priceType == 'range')
                      TextField(
                        controller: max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'ราคาสูงสุด',
                          suffixText: 'บาท',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (item != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดให้ลูกค้าเห็นบริการ'),
                        value: active,
                        onChanged: (value) {
                          refresh(() => active = value);
                        },
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: savingSheet
                            ? null
                            : () async {
                                final low = double.tryParse(min.text.trim());
                                final high = priceType == 'range'
                                    ? double.tryParse(max.text.trim())
                                    : null;

                                if (nameTh.text.trim().isEmpty ||
                                    low == null ||
                                    low < 0 ||
                                    (priceType == 'range' &&
                                        (high == null || high < low))) {
                                  _message('กรุณาตรวจสอบข้อมูลและราคา');
                                  return;
                                }

                                refresh(() => savingSheet = true);

                                final rawTitle = nameTh.text.trim();
                                final taggedNameTh =
                                    rawTitle.toLowerCase().contains(
                                              selectedCategory.toLowerCase(),
                                            )
                                        ? rawTitle
                                        : '$selectedCategory • $rawTitle';

                                final rawDesc = description.text.trim();
                                final taggedDesc = rawDesc.isEmpty
                                    ? 'หมวดหมู่: $selectedCategory'
                                    : (rawDesc.toLowerCase().contains(
                                            selectedCategory.toLowerCase(),
                                          )
                                        ? rawDesc
                                        : '[$selectedCategory] $rawDesc');

                                try {
                                  if (item == null) {
                                    await _service.addPrice(
                                      nameTh: taggedNameTh,
                                      nameEn: nameEn.text.trim(),
                                      descriptionTh: taggedDesc,
                                      priceType: priceType,
                                      minPrice: low,
                                      maxPrice: high,
                                    );
                                  } else {
                                    await _service.updatePrice(
                                      id: item.id,
                                      nameTh: taggedNameTh,
                                      nameEn: nameEn.text.trim(),
                                      descriptionTh: taggedDesc,
                                      priceType: priceType,
                                      minPrice: low,
                                      maxPrice: high,
                                      isActive: active,
                                    );
                                  }

                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  if (!mounted) return;

                                  _loadPrices();
                                  _message('บันทึกข้อมูลเรียบร้อย');
                                } catch (e) {
                                  if (modalContext.mounted) {
                                    refresh(() => savingSheet = false);
                                  }
                                  if (!mounted) return;
                                  _message('บันทึกไม่สำเร็จ: $e');
                                }
                              },
                        child: Text(
                          savingSheet ? 'กำลังบันทึก...' : 'บันทึกบริการ',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameTh.dispose();
    nameEn.dispose();
    min.dispose();
    max.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _techAvatarUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('รายการและเรตราคาบริการ'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'คิวงานของช่าง',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TechnicianJobsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(onPressed: _loadPrices, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มบริการ'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECEEF5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEDE7FF),
                  backgroundImage:
                      hasAvatar ? NetworkImage(_techAvatarUrl) : null,
                  child: !hasAvatar
                      ? const Icon(Icons.engineering, color: primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _techName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'รายการบริการที่แสดงให้ลูกค้าเห็น',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TechnicianJobsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                  label: const Text('คิวงาน'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _prices.isEmpty
                    ? const Center(child: Text('ยังไม่มีรายการราคาบริการ'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _prices.length,
                        itemBuilder: (context, index) {
                          final item = _prices[index] as TechnicianServicePrice;
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFECEEF5)),
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.handyman_outlined,
                                  color: Color(0xFF4F46E5),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                item.nameTh,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              subtitle: Text(
                                '${_formatPrice(item)}${item.isActive ? '' : ' • ปิดใช้งาน'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: item.isActive
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    tooltip: 'แก้ไข',
                                    onPressed: () => _openForm(item: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFDC2626),
                                    ),
                                    tooltip: 'ลบ',
                                    onPressed: () => _confirmDelete(item),
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
    );
  }
}