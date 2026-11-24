import 'package:flutter/material.dart';

import '../../services/admin_user_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminUserService _service = AdminUserService();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getUserDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดรายละเอียดไม่สำเร็จ: $e')));
    }
  }

  Future<void> _changeStatus(bool suspend) async {
    final reasonController = TextEditingController();
    String? validationError;

    final reason = suspend
        ? await showDialog<String>(
            context: context,
            builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('ระงับบัญชีสมาชิก'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText:
                            'ระบุเหตุผลในการระงับบัญชี (อย่างน้อย 3 ตัวอักษร)',
                        border: const OutlineInputBorder(),
                        errorText: validationError,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final value = reasonController.text.trim();
                      if (value.length < 3) {
                        setDialogState(() {
                          validationError =
                              'กรุณาระบุเหตุผลอย่างน้อย 3 ตัวอักษร';
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, value);
                    },
                    child: const Text('ยืนยัน'),
                  ),
                ],
              ),
            ),
          )
        : '';

    reasonController.dispose();

    if (reason == null) return;
    if (!mounted) return;

    setState(() => _working = true);

    try {
      await _service.changeAccountStatus(
        targetUserId: widget.userId,
        action: suspend ? 'suspend' : 'activate',
        reason: reason,
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? 'ระงับบัญชีเรียบร้อยแล้ว'
                : 'เปิดใช้งานบัญชีเรียบร้อยแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ดำเนินการไม่สำเร็จ: $e')));
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'technician':
        return 'ช่าง';
      case 'customer':
        return 'ลูกค้า';
      case 'admin':
        return 'ผู้ดูแลระบบ (Admin)';
      default:
        return role;
    }
  }

  Widget _info(String title, dynamic value) {
    final text = value?.toString().trim();
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      subtitle: Text(
        (text != null && text.isNotEmpty) ? text : '-',
        style: const TextStyle(color: Colors.black87, fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        appBar: AppBar(
          title: const Text('รายละเอียดสมาชิก'),
          backgroundColor: Colors.white,
        ),
        body: Center(child: Text(_error ?? 'ไม่พบข้อมูลสมาชิก')),
      );
    }

    final profile = Map<String, dynamic>.from(_data!['profile'] as Map);
    final technician = _data!['technician'] is Map
        ? Map<String, dynamic>.from(_data!['technician'] as Map)
        : null;

    final role = profile['role']?.toString() ?? '-';
    final fullName = profile['full_name']?.toString().trim();
    final avatarUrl = profile['avatar_url']?.toString().trim() ??
        technician?['avatar_url']?.toString().trim() ??
        '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final suspended = profile['account_status'] == 'suspended';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('รายละเอียดสมาชิก'),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFEFE8FF),
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar
                        ? Icon(
                            role == 'technician' ? Icons.build : Icons.person,
                            size: 38,
                            color: const Color(0xFF7041D8),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (fullName != null && fullName.isNotEmpty)
                        ? fullName
                        : 'ไม่ระบุชื่อ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _roleLabel(role),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Chip(
                    label: Text(suspended ? 'ระงับบัญชี' : 'บัญชีใช้งานปกติ'),
                    backgroundColor: suspended
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                  ),
                  const Divider(),
                  _info('User ID', profile['id']),
                  _info('เบอร์โทรศัพท์', profile['phone']),
                  _info('วันที่สมัคร', profile['created_at']),
                  if (suspended) ...[
                    _info('วันที่ระงับ', profile['suspended_at']),
                    _info('เหตุผลที่ระงับ', profile['suspension_reason']),
                  ],
                ],
              ),
            ),
            if (technician != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'ข้อมูลช่าง',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    ...technician.entries
                        .where((e) => !['id', 'user_id'].contains(e.key))
                        .map((e) => _info(e.key, e.value)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: suspended ? Colors.green : Colors.red,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _working ? null : () => _changeStatus(!suspended),
              icon: Icon(suspended ? Icons.lock_open : Icons.block),
              label: Text(suspended ? 'เปิดใช้งานบัญชี' : 'ระงับบัญชี'),
            ),
          ],
        ),
      ),
    );
  }
}