class BookingModel {
  final String id;
  final String? jobNumber;
  final String customerId;
  final String technicianId;
  final String? jobPostId;
  final String? customerName;
  final String? customerPhone;
  final String? description;
  final String? serviceAddress;
  final DateTime scheduledAt;
  final String status;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  const BookingModel({
    required this.id,
    this.jobNumber,
    required this.customerId,
    required this.technicianId,
    this.jobPostId,
    this.customerName,
    this.customerPhone,
    this.description,
    this.serviceAddress,
    required this.scheduledAt,
    required this.status,
    this.cancelledAt,
    this.cancelledBy,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'].toString(),
      jobNumber: map['job_number']?.toString(),
      customerId: map['customer_id'].toString(),
      technicianId: map['technician_id'].toString(),
      jobPostId: map['job_post_id']?.toString(),
      customerName: map['customer_name']?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      description: map['description']?.toString(),
      serviceAddress: map['service_address']?.toString(),
      scheduledAt:
          DateTime.tryParse(map['scheduled_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
      cancelledAt: map['cancelled_at'] != null
          ? DateTime.tryParse(map['cancelled_at'].toString())?.toLocal()
          : null,
      cancelledBy: map['cancelled_by']?.toString(),
    );
  }
}