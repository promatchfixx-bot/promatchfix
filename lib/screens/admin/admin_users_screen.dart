import 'package:flutter/material.dart';

import '../../models/admin_user_model.dart';
import '../../services/admin_user_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final service = AdminUserService();
  final searchController = TextEditingController();

  List<AdminUser> users = [];
  bool loading = true;
  String role = 'all';
  int page = 0;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadUsers() async {
    setState(() => loading = true);

    try {
      final result = await service.getUsers(
        role: role,
        keyword: searchController.text,
        page: page,
      );

      if (!mounted) return;
      setState(() {
        users = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดสมาชิกไม่สำเร็จ: $e')));
    }
  }

  String roleLabel(String role) {
    switch (role) {
      case 'technician':
        return 'ช่าง';
      case 'customer':
        return 'ลูกค้า';
      case 'admin':
        return 'ผู้ดูแล';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('จัดการสมาชิก'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onSubmitted: (_) {
                page = 0;
                loadUsers();
              },
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสมาชิก',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    searchController.clear();
                    page = 0;
                    loadUsers();
                  },
                  icon: const Icon(Icons.close),
                ),
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
              initialValue: role,
              decoration: const InputDecoration(
                labelText: 'ประเภทสมาชิก',
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'technician', child: Text('ช่าง')),
                DropdownMenuItem(value: 'customer', child: Text('ลูกค้า')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                role = value ?? 'all';
                page = 0;
                loadUsers();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                ? const Center(child: Text('ไม่พบสมาชิก'))
                : RefreshIndicator(
                    onRefresh: loadUsers,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final suspended = user.accountStatus == 'suspended';

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEFE8FF),
                              child: Icon(
                                user.role == 'technician'
                                    ? Icons.build
                                    : Icons.person,
                                color: const Color(0xFF7041D8),
                              ),
                            ),
                            title: Text(
                              user.fullName ?? 'ไม่ระบุชื่อ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${roleLabel(user.role)} • ${user.phone ?? '-'}\n${suspended ? 'ระงับบัญชี' : 'ใช้งานปกติ'}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminUserDetailScreen(userId: user.id),
                                ),
                              );
                              loadUsers();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (!loading)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('หน้า ${page + 1}'),
                  Row(
                    children: [
                      IconButton(
                        onPressed: page > 0
                            ? () {
                                page--;
                                loadUsers();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        onPressed: users.length == 20
                            ? () {
                                page++;
                                loadUsers();
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
