import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/kyc_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _service = KycService();

  PlatformFile? _selectedFile;
  Uint8List? _selectedBytes;
  bool _loading = false;
  bool _loadingStatus = true;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final result = await _service.getMyKycStatus();

      if (!mounted) return;

      setState(() {
        _status = result;
        _loadingStatus = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingStatus = false);
      _showMessage('โหลดสถานะไม่สำเร็จ: $e');
    }
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;

    if (bytes.isEmpty) {
      _showMessage('ไม่สามารถอ่านไฟล์รูปภาพได้');
      return;
    }

    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('รูปภาพต้องมีขนาดไม่เกิน 5 MB');
      return;
    }

    setState(() {
      _selectedFile = file;
      _selectedBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null || _selectedBytes == null) {
      _showMessage('กรุณาเลือกรูปบัตรประชาชน');
      return;
    }

    setState(() => _loading = true);

    try {
      final fileName = _selectedFile!.name;
      final extension = fileName.split('.').last.toLowerCase();

      await _service.submitKyc(
        nationalId: _idController.text.trim(),
        imageBytes: _selectedBytes!,
        fileExtension: extension,
      );

      _idController.clear();

      if (!mounted) return;

      setState(() {
        _selectedFile = null;
        _selectedBytes = null;
        _loading = false;
      });

      await _loadStatus();

      if (!mounted) return;

      _showMessage('ส่งเอกสารเรียบร้อยแล้ว');
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage(e.toString());
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusText(String? status) {
    switch (status) {
      case 'pending':
        return 'กำลังรอตรวจสอบ';
      case 'approved':
        return 'ยืนยันตัวตนสำเร็จ';
      case 'rejected':
        return 'เอกสารไม่ผ่านการตรวจสอบ';
      default:
        return 'ยังไม่ยืนยันตัวตน';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = _status?['status'] as String?;

    final canSubmit = currentStatus == null || currentStatus == 'rejected';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('ยืนยันตัวตนช่าง'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loadingStatus
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF7041D8),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ยืนยันตัวตนของคุณ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'กรุณากรอกเลขบัตรประชาชนและแนบรูปบัตร '
                      'เพื่อให้ผู้ดูแลระบบตรวจสอบ',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: Color(0xFF7041D8),
                        ),
                        title: const Text('สถานะ KYC'),
                        subtitle: Text(_statusText(currentStatus)),
                      ),
                    ),
                    if (currentStatus == 'rejected')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'เหตุผล: ${_status?['rejection_reason'] ?? 'กรุณาตรวจสอบเอกสาร'}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (currentStatus == 'approved')
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'บัญชีของคุณผ่านการยืนยันตัวตนแล้ว',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (canSubmit) ...[
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เลขบัตรประชาชน 13 หลัก',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _idController,
                              keyboardType: TextInputType.number,
                              maxLength: 13,
                              decoration: const InputDecoration(
                                hintText: 'กรอกเลขบัตรประชาชน',
                                prefixIcon: Icon(Icons.credit_card_outlined),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null ||
                                    value.length != 13 ||
                                    !RegExp(r'^[0-9]{13}$').hasMatch(value)) {
                                  return 'กรุณากรอกเลขบัตร 13 หลัก';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'รูปบัตรประชาชนด้านหน้า',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _loading ? null : _pickImage,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('เลือกรูปบัตรประชาชน'),
                            ),
                            if (_selectedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'ไฟล์: ${_selectedFile!.name}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text('ส่งข้อมูลยืนยันตัวตน'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ข้อมูลและเอกสารจะถูกใช้เพื่อการตรวจสอบตัวตน '
                              'ตามวัตถุประสงค์ที่แจ้งไว้เท่านั้น',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
