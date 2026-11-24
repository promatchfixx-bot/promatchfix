import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewComplaintService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('กรุณาเข้าสู่ระบบก่อนใช้งาน');
    return id;
  }

  submitReview({
    required String bookingId,
    String? jobNumber,
    required String technicianId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('กรุณาเลือกคะแนนดาว 1 ถึง 5 ดาว');
    }

    await _client.from('reviews').insert({
      'booking_id': bookingId,
      'job_number': jobNumber,
      'customer_id': _userId,
      'technician_id': technicianId,
      'rating': rating,
      'comment': comment?.trim(),
    });
  }

  submitComplaint({
    required String bookingId,
    String? jobNumber,
    String? technicianId,
    required String subject,
    required String details,
  }) async {
    if (subject.trim().isEmpty) {
      throw Exception('กรุณาระบุหัวข้อที่ต้องการร้องเรียน');
    }
    if (details.trim().isEmpty) {
      throw Exception('กรุณาระบุรายละเอียดข้อร้องเรียน');
    }

    await _client.from('complaints').insert({
      'booking_id': bookingId,
      'job_number': jobNumber,
      'customer_id': _userId,
      'technician_id': technicianId,
      'subject': subject.trim(),
      'details': details.trim(),
      'status': 'open',
    });
  }

  getReviewsForTechnician(String technicianId) async {
    final rows = await _client
        .from('reviews')
        .select('*')
        .eq('technician_id', technicianId)
        .order('created_at', ascending: false);
    return List.from(rows);
  }

  getAllReviewsForAdmin() async {
    final rows = await _client
        .from('reviews')
        .select('*')
        .order('created_at', ascending: false);
    return List.from(rows);
  }

  getAllComplaintsForAdmin() async {
    final rows = await _client
        .from('complaints')
        .select('*')
        .order('created_at', ascending: false);
    return List.from(rows);
  }

  updateComplaintStatus(String complaintId, String nextStatus) async {
    await _client
        .from('complaints')
        .update({'status': nextStatus})
        .eq('id', complaintId);
  }
}