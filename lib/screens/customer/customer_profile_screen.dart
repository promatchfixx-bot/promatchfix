import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  static const Color primary = Color(0xFF7041D8);

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  Uint8List? _pickedPreviewBytes;
  String _preferredLanguage = 'th';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? get _uid => _client.auth.currentUser?.id;

  String? get _email => _client.auth.currentUser?.email;

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final row = await _client
          .from('profiles')
          .select('*')
          .eq('id', uid)
          .maybeSingle();

      if (!mounted) return;

      if (row != null) {
        _nameController.text = row['full_name']?.toString() ?? '';
        _phoneController.text = row['phone']?.toString() ?? '';
        final av = row['avatar_url']?.toString().trim() ?? '';
        _avatarUrl = av.isNotEmpty ? av : null;
        final lang = row['preferred_language']?.toString().trim() ?? '';
        if (lang.isNotEmpty) {
          _preferredLanguage = lang;
        }
      } else {
        final metaName =
            _client.auth.currentUser?.userMetadata?['full_name']?.toString() ??
                '';
        _nameController.text = metaName;
      }

      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMsg('โหลดโปรไฟล์ไม่สำเร็จ: $e');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final uid = _uid;
    if (uid == null) {
      _showMsg('กรุณาเข้าสู่ระบบก่อน');
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
      final nameParts = picked.name.split('.');
      final rawExt =
          nameParts.length > 1 ? nameParts.last.toLowerCase() : 'jpg';
      final ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
      final storagePath = 'customers/$uid/avatar.$ext';

      await _client.storage.from('avatars').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$ext',
            ),
          );

      final publicUrl =
          _client.storage.from('avatars').getPublicUrl(storagePath);
      final cacheBustedUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await _client.from('profiles').upsert({
        'id': uid,
        'full_name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (_email?.split('@').first ?? 'ลูกค้า'),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'role': 'customer',
        'avatar_url': cacheBustedUrl,
        'preferred_language': _preferredLanguage,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() {
        _pickedPreviewBytes = bytes;
        _avatarUrl = cacheBustedUrl;
        _uploadingAvatar = false;
      });
      _showMsg('อัปโหลดรูปโปรไฟล์เรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      _showMsg('อัปโหลดรูปไม่สำเร็จ: $e');
    }
  }

  Future<void> _saveProfile() async {
    final uid = _uid;
    if (uid == null) {
      _showMsg('กรุณาเข้าสู่ระบบก่อน');
      return;
    }

    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      _showMsg('กรุณากรอกชื่อ-นามสกุล');
      return;
    }

    setState(() => _saving = true);
    try {
      await _client.from('profiles').upsert({
        'id': uid,
        'full_name': fullName,
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'role': 'customer',
        'avatar_url': _avatarUrl,
        'preferred_language': _preferredLanguage,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() => _saving = false);
      _showMsg('บันทึกโปรไฟล์เรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMsg('บันทึกไม่สำเร็จ: $e');
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ImageProvider? _avatarProvider() {
    if (_pickedPreviewBytes != null) {
      return MemoryImage(_pickedPreviewBytes!);
    }
    if (_avatarUrl != null && _avatarUrl!.trim().isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _avatarProvider();
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'ผู้ใช้งานลูกค้า';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
        backgroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFEDE7FF),
                                backgroundImage: provider,
                                child: _uploadingAvatar
                                    ? const CircularProgressIndicator()
                                    : provider == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 46,
                                            color: primary,
                                          )
                                        : null,
                              ),
                              Material(
                                color: primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _uploadingAvatar
                                      ? null
                                      : _pickAndUploadAvatar,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((_email ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _email!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _uploadingAvatar
                                ? null
                                : _pickAndUploadAvatar,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _uploadingAvatar
                                  ? 'กำลังอัปโหลดรูป...'
                                  : 'เลือกรูปโปรไฟล์',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'ชื่อ-นามสกุล',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทรศัพท์',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'บันทึกโปรไฟล์',
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