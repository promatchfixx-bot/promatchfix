class TechnicianSubscription {
  final String id;
  final String status;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  const TechnicianSubscription({
    required this.id,
    required this.status,
    this.startsAt,
    this.expiresAt,
  });

  factory TechnicianSubscription.fromMap(Map<String, dynamic> map) {
    return TechnicianSubscription(
      id: map['id'].toString(),
      status: map['status'] ?? 'pending',
      startsAt: map['starts_at'] == null
          ? null
          : DateTime.tryParse(map['starts_at']),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.tryParse(map['expires_at']),
    );
  }

  bool get isActive =>
      status == 'active' &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now().toUtc());
}
