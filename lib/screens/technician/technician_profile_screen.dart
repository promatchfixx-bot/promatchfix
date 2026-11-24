import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _client = Supabase.instance.client;
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _inspectionController = TextEditingController();
  final _travelController = TextEditingController();

  TechnicianModel? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  Uint8List? _pickedPreviewBytes;
  String? _uploadedAvatarUrl;
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

  bool _isProfileNotFoundError(Object error) {
    final msg = error.toString();
    return msg.contains('ไม่พบข้อมูลโปรไฟล์ช่าง');
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

      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        try {
          final pRow = await _client
              .from('profiles')
              .select('avatar_url, full_name, phone')
              .eq('id', uid)
              .maybeSingle();
          final pAvatar = pRow?['avatar_url']?.toString().trim() ?? '';
          if (pAvatar.isNotEmpty) {
            _uploadedAvatarUrl = pAvatar;
          }
          if (_nameController.text.trim().isEmpty &&
              pRow?['full_name']?.toString().trim().isNotEmpty == true) {
            _nameController.text = pRow!['full_name'].toString().trim();
          }
          if (_phoneController.text.trim().isEmpty &&
              pRow?['phone']?.toString().trim().isNotEmpty == true) {
            _phoneController.text = pRow!['phone'].toString().trim();
          }
        } catch (_) {}
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;

      if (_isProfileNotFoundError(e)) {
        _profile = null;
        _nameController.text = '';
        _phoneController.text = '';
        _provinceController.text = '';
        _districtController.text = '';
        _inspectionController.text = '0';
        _travelController.text = '0';
        setState(() {
          _error = null;
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = _client.auth.currentUser;
    final uid = user?.id;
    if (uid == null) {
      _message('กรุณาเข้าสู่ระบบก่อน');
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final parts = picked.name.split('.');
      final rawExt = parts.length > 1 ? parts.last.toLowerCase() : 'jpg';
      final ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
      final storagePath = 'technicians/$uid/avatar.$ext';

      await _client.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$ext',
            ),
          );

      final url =
          '${_client.storage.from('avatars').getPublicUrl(storagePath)}?v=${DateTime.now().millisecondsSinceEpoch}';

      final fallbackName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (user?.email?.split('@').first ?? 'ช่าง');

      await _client.from('profiles').upsert({
        'id': uid,
        'full_name': fallbackName,
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'role': 'technician',
        'avatar_url': url,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        _pickedPreviewBytes = bytes;
        _uploadedAvatarUrl = url;
        _uploadingAvatar = false;
      });
      _message('อัปโหลดรูปโปรไฟล์ช่างเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      _message('อัปโหลดรูปไม่สำเร็จ: $e');
    }
  }

  Future<void> _saveProfile() async {
    final inspection = double.tryParse(_inspectionController.text.trim());
    final travel = double.tryParse(_travelController.text.trim());

    if (inspection == null || travel == null) {
      _message('กรุณากรอกค่าบริการเป็นตัวเลข');
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.updateMyProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        province: _provinceController.text.trim(),
        district: _districtController.text.trim(),
        inspectionFee: inspection,
        travelFeePerKm: travel,
        latitude: _profile?.latitude,
        longitude: _profile?.longitude,
      );

      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        try {
          await _client.from('profiles').upsert({
            'id': uid,
            'full_name': _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : 'ช่าง',
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'role': 'technician',
            if (_uploadedAvatarUrl != null) 'avatar_url': _uploadedAvatarUrl,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      await _loadProfile();

      if (!mounted) return;
      _message('บันทึกข้อมูลเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      _message(
        'บันทึกไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}',
      );
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

  ImageProvider? _avatarProvider() {
    if (_pickedPreviewBytes != null) {
      return MemoryImage(_pickedPreviewBytes!);
    }
    final activeUrl = _uploadedAvatarUrl ?? _profile?.avatarUrl;
    if (activeUrl != null && activeUrl.trim().isNotEmpty) {
      return NetworkImage(activeUrl);
    }
    return null;
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

    final profile = _profile;
    final provider = _avatarProvider();
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : ((profile?.fullName?.trim().isNotEmpty == true)
            ? profile!.fullName!
            : 'ช่างใหม่ (ยังไม่บันทึกโปรไฟล์)');
    final areaText = (profile?.province != null || profile?.district != null)
        ? '${profile?.province ?? '-'} / ${profile?.district ?? '-'}'
        : 'กรุณาระบุพื้นที่ให้บริการ';

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
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: const Color(0xFFEDE7FF),
                          backgroundImage: provider,
                          child: _uploadingAvatar
                              ? const CircularProgressIndicator()
                              : provider == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Color(0xFF7041D8),
                                    )
                                  : null,
                        ),
                        Material(
                          color: const Color(0xFF7041D8),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _uploadingAvatar
                            ? 'กำลังอัปโหลดรูป...'
                            : 'เลือกรูปโปรไฟล์',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(areaText, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: Icon(
                            (profile?.isApproved ?? false)
                                ? Icons.verified
                                : Icons.pending,
                            size: 18,
                          ),
                          label: Text(
                            (profile?.isApproved ?? false)
                                ? 'อนุมัติแล้ว'
                                : 'รออนุมัติ',
                          ),
                        ),
                        Chip(
                          label: Text(
                            (profile?.isOnline ?? false)
                                ? 'ออนไลน์'
                                : 'ออฟไลน์',
                          ),
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