import 'package:flutter/material.dart';

import '../../models/technician_service_price_model.dart';
import '../../services/technician_pricing_service.dart';

class TechnicianPricingScreen extends StatefulWidget {
  const TechnicianPricingScreen({super.key});

  @override
  State<TechnicianPricingScreen> createState() =>
      _TechnicianPricingScreenState();
}

class _TechnicianPricingScreenState extends State<TechnicianPricingScreen> {
  final TechnicianPricingService _service = TechnicianPricingService();
  List<TechnicianServicePrice> _prices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final items = await _service.getMyPrices();
      if (!mounted) return;
      setState(() {
        _prices = items;
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

  Future<void> _confirmDelete(TechnicianServicePrice item) async {
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
      await _loadPrices();
      if (!mounted) return;
      _message('ลบบริการเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      _message('ลบไม่สำเร็จ: $e');
    }
  }

  Future<void> _openForm({TechnicianServicePrice? item}) async {
    final nameTh = TextEditingController(text: item?.nameTh ?? '');
    final nameEn = TextEditingController(text: item?.nameEn ?? '');
    final min = TextEditingController(
      text: item != null ? item.minPrice.toStringAsFixed(0) : '',
    );
    final max = TextEditingController(
      text: item?.maxPrice != null ? item!.maxPrice!.toStringAsFixed(0) : '',
    );
    final description = TextEditingController(text: item?.descriptionTh ?? '');

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
                      key: ValueKey(priceType),
                      value: priceType,
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

                                try {
                                  if (item == null) {
                                    await _service.addPrice(
                                      nameTh: nameTh.text.trim(),
                                      nameEn: nameEn.text.trim(),
                                      descriptionTh: description.text.trim(),
                                      priceType: priceType,
                                      minPrice: low,
                                      maxPrice: high,
                                    );
                                  } else {
                                    await _service.updatePrice(
                                      id: item.id,
                                      nameTh: nameTh.text.trim(),
                                      nameEn: nameEn.text.trim(),
                                      descriptionTh: description.text.trim(),
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

                                  await _loadPrices();
                                  if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('จัดการราคาค่าบริการ'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadPrices, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มบริการ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _prices.isEmpty
          ? const Center(child: Text('ยังไม่มีรายการราคาบริการ'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prices.length,
              itemBuilder: (context, index) {
                final item = _prices[index];
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
    );
  }
}
