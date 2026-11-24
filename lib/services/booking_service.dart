import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';

class BookingService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw Exception('กรุณาเข้าสู่ระบบ');
    }
    return id;
  }

  Future<BookingModel> createBooking({
    required String technicianId,
    required DateTime scheduledAt,
    required String customerName,
    required String customerPhone,
    required String description,
    String? serviceAddress,
    int? categoryId,
    String? jobPostId,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) {
      throw Exception('กรุณาเลือกวันและเวลาในอนาคต');
    }

    if (customerName.trim().isEmpty ||
        customerPhone.trim().isEmpty ||
        description.trim().isEmpty) {
      throw Exception('กรุณากรอกข้อมูลให้ครบถ้วน');
    }

    final payload = {
      'customer_id': _userId,
      'technician_id': technicianId,
      'job_post_id': jobPostId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'customer_name': customerName.trim(),
      'customer_phone': customerPhone.trim(),
      'description': description.trim(),
      'service_address': serviceAddress?.trim(),
      'category_id': categoryId,
      'status': 'pending',
    };

    final response = await _client
        .from('bookings')
        .insert(payload)
        .select()
        .single();

    return BookingModel.fromMap(Map<String, dynamic>.from(response));
  }

  Future<List<BookingModel>> getTechnicianBookings({
    DateTime? date,
  }) async {
    var query = _client.from('bookings').select().eq('technician_id', _userId);

    if (date != null) {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      query = query
          .gte('scheduled_at', start.toUtc().toIso8601String())
          .lt('scheduled_at', end.toUtc().toIso8601String());
    }

    final rows = await query.order('scheduled_at');
    return List.from(rows)
        .map((e) => BookingModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<BookingModel>> getCustomerBookings() async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('customer_id', _userId)
        .order('scheduled_at', ascending: false);

    return List.from(rows)
        .map((e) => BookingModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> respondToBooking({
    required String bookingId,
    required bool accept,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updates = {
      'status': accept ? 'accepted' : 'rejected',
      if (accept) 'accepted_at': nowIso,
      if (!accept) 'rejected_at': nowIso,
    };

    final result = await _client
        .from('bookings')
        .update(updates)
        .eq('id', bookingId)
        .eq('technician_id', _userId)
        .eq('status', 'pending')
        .select();

    if (List.from(result).isEmpty) {
      throw Exception('ไม่พบรายการจอง หรือรายการนี้ถูกดำเนินการแล้ว');
    }
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    const allowed = {'in_progress', 'completed'};

    if (!allowed.contains(status)) {
      throw Exception('สถานะงานไม่ถูกต้อง');
    }

    final requiredCurrentStatus =
        status == 'completed' ? 'in_progress' : 'accepted';

    final updates = {
      'status': status,
      if (status == 'completed')
        'completed_at': DateTime.now().toUtc().toIso8601String(),
    };

    final result = await _client
        .from('bookings')
        .update(updates)
        .eq('id', bookingId)
        .eq('technician_id', _userId)
        .eq('status', requiredCurrentStatus)
        .select();

    if (List.from(result).isEmpty) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะงานได้');
    }
  }

  Future<void> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cleanReason = reason?.trim() ?? '';

    final bookingRow = await _client
        .from('bookings')
        .select('id, technician_id, job_post_id, status')
        .eq('id', bookingId)
        .eq('customer_id', _userId)
        .maybeSingle();

    final result = await _client
        .from('bookings')
        .update({
          'status': 'cancelled',
          'cancelled_at': nowIso,
          'cancelled_by': _userId,
          if (cleanReason.isNotEmpty) 'cancellation_reason': cleanReason,
        })
        .eq('id', bookingId)
        .eq('customer_id', _userId)
        .inFilter('status', ['pending', 'accepted'])
        .select();

    if (List.from(result).isEmpty) {
      throw Exception('ไม่สามารถยกเลิกการจองนี้ได้');
    }

    if (bookingRow != null && cleanReason.isNotEmpty) {
      final techId = bookingRow['technician_id']?.toString();
      if (techId != null && techId.isNotEmpty) {
        await _client.from('job_cancellation_feedbacks').insert({
          'booking_id': bookingId,
          'job_post_id': bookingRow['job_post_id'],
          'customer_id': _userId,
          'technician_id': techId,
          'reason': cleanReason,
        });
      }
    }
  }
}