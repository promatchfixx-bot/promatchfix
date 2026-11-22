import 'package:flutter/material.dart';

import '../../models/technician_model.dart';
import '../../services/technician_service.dart';

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({super.key});

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  final _service = TechnicianService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _inspectionController = TextEditingController();
  final _travelController = TextEditingController();

  TechnicianModel? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _inspectionController.dispose();
    _travelController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getMyProfile();

      if (!mounted) return;

      _profile = result;
      _nameController.text = result.fullName ?? '';
      _phoneController.text = result.phone ?? '';
      _provinceController.text = result.province ?? '';
      _districtController.text = result.district ?? '';
      _inspectionController.text = result.inspectionFee.toStringAsFixed(0);
      _travelController.text = result.travelFeePerKm.toStringAsFixed(0);

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final inspection = double.tryParse(_inspectionController.text);
    final travel = double.tryParse(_travelController.text);

    if (inspection == null || travel == null) {
      _message('กรุณากรอกค่าบริการเป็นตัวเลข');
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.updateMyProfile(
        fullName: _nameController.text,
        phone: _phoneController.text,
        province: _provinceController.text,
        district: _districtController.text,
        inspectionFee: inspection,
        travelFeePerKm: travel,
        latitude: _profile?.latitude,
        longitude: _profile?.longitude,
      );

      await _loadProfile();

      if (!mounted) return;
      _message('บันทึกข้อมูลเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      _message('บันทึกไม่สำเร็จ: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('โปรไฟล์ช่าง')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadProfile,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: const Text('โปรไฟล์ช่าง'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFEDE7FF),
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: Color(0xFF7041D8),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName ?? 'ช่าง',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${profile.province ?? '-'} / ${profile.district ?? '-'}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(
                            profile.isApproved ? Icons.verified : Icons.pending,
                            size: 18,
                          ),
                          label: Text(
                            profile.isApproved ? 'อนุมัติแล้ว' : 'รออนุมัติ',
                          ),
                        ),
                        Chip(
                          label: Text(profile.isOnline ? 'ออนไลน์' : 'ออฟไลน์'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ข้อมูลส่วนตัว',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _field('ชื่อ-นามสกุล', _nameController),
            _field(
              'เบอร์โทรศัพท์',
              _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            const Text(
              'พื้นที่ให้บริการ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _field('จังหวัด', _provinceController),
            _field('อำเภอ / เขต', _districtController),
            const SizedBox(height: 8),
            const Text(
              'ค่าบริการ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _field(
              'ค่าตรวจเช็ค (บาท)',
              _inspectionController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            _field(
              'ค่าเดินทางต่อกิโลเมตร (บาท)',
              _travelController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7041D8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'บันทึกข้อมูล',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
