class AdminUser {
  final String id;
  final String? fullName;
  final String? phone;
  final String role;
  final String accountStatus;
  final DateTime? createdAt;

  const AdminUser({
    required this.id,
    this.fullName,
    this.phone,
    required this.role,
    required this.accountStatus,
    this.createdAt,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'].toString(),
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      role: map['role'] ?? 'unknown',
      accountStatus: map['account_status'] ?? 'active',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}
