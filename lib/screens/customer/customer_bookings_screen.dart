import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../services/booking_service.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  final BookingService _service = BookingService();
  final SupabaseClient _client = Supabase.instance.client;

  bool _loading = true;
  List<BookingModel> _bookings = [];
  Set<String> _reviewedBookingIds = {};
  Map<String, Map<String, dynamic>> _technicianProfilesById = {};
  RealtimeChannel? _bookingsChannel;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _subscribeBookingsRealtime();
  }

  @override
  void dispose() {
    if (_bookingsChannel != null) {
      _client.removeChannel(_bookingsChannel!);
    }
    super.dispose();
  }

  void _subscribeBookingsRealtime() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    _bookingsChannel = _client
        .channel('customer_bookings_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: uid,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newStatus = payload.newRecord['status']?.toString() ?? '';
            if (newStatus == 'accepted') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ช่างตอบรับงานแล้ว! อัปเดตในหน้าการจองของฉัน'),
                ),
              );
            }
            _loadBookings(showSpinner: false);
          },
        )
        .subscribe();
  }

  int _sortPriority(BookingModel b) {
    final reviewed = _reviewedBookingIds.contains(b.id);
    if (b.status == 'in_progress') {
      return 1;
    }
    if (b.status == 'completed' && !reviewed) {
      return 2;
    }
    if (b.status == 'completed' && reviewed) {
      return 3;
    }
    if (b.status == 'cancelled' || b.status == 'rejected') {
      return 4;
    }
    return 0;
  }

  List<BookingModel> _sortBookings(
    List<BookingModel> raw,
    Set<String> reviewedIds,
  ) {
    final copy = List<BookingModel>.from(raw);
    copy.sort((a, b) {
      final pa = _sortPriority(a);
      final pb = _sortPriority(b);
      if (pa != pb) return pa.compareTo(pb);
      return a.scheduledAt.compareTo(b.scheduledAt);
    });
    return copy;
  }

  Future<void> _loadTechnicianProfiles(List<BookingModel> bookingList) async {
    final map = <String, Map<String, dynamic>>{};
    final ids = <String>{};

    for (final b in bookingList) {
      final tid = b.technicianId.trim();
      if (tid.isNotEmpty) {
        ids.add(tid);
      }
    }

    if (ids.isNotEmpty) {
      try {
        final rows = await _client
            .from('profiles')
            .select('id, full_name, avatar_url, phone')
            .inFilter('id', ids.toList());

        for (final row in List.from(rows)) {
          if (row is Map) {
            final pid = row['id']?.toString().trim() ?? '';
            if (pid.isNotEmpty) {
              map[pid] = Map<String, dynamic>.from(row);
            }
          }
        }
      } catch (_) {}
    }

    _technicianProfilesById = map;
  }

  Widget _technicianProfileRow(BookingModel booking) {
    final tid = booking.technicianId.trim();
    final profile = tid.isNotEmpty ? _technicianProfilesById[tid] : null;
    final profileName = profile?['full_name']?.toString().trim() ?? '';
    final displayName = profileName.isNotEmpty ? profileName : 'ช่างผู้ให้บริการ';
    final avatarUrl = profile?['avatar_url']?.toString().trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final phone = profile?['phone']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFEDE7FF),
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
            child: !hasAvatar
                ? const Icon(
                    Icons.engineering,
                    size: 18,
                    color: Color(0xFF7041D8),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ช่าง: $displayName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  phone.isNotEmpty ? 'โทร: $phone' : 'ผู้รับผิดชอบงาน',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBookings({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() => _loading = true);
    }
    try {
      final rows = await _service.getCustomerBookings();
      final uid = _client.auth.currentUser?.id;
      Set<String> reviewedIds = {};

      if (uid != null) {
        final reviewedRows = await _client
            .from('reviews')
            .select('booking_id')
            .eq('customer_id', uid);
        reviewedIds = List.from(reviewedRows)
            .map((e) => (e as Map)['booking_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
      }

      await _loadTechnicianProfiles(rows);

      if (!mounted) return;
      setState(() {
        _reviewedBookingIds = reviewedIds;
        _bookings = _sortBookings(rows, reviewedIds);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดรายการจองไม่สำเร็จ: $e')),
      );
    }
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการจ้างและส่งเหตุผลให้ช่าง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'งาน: ${booking.jobNumber ?? booking.id}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'เหตุผลที่เลิกจ้าง (ส่งเหตุผลให้ช่าง)',
                hintText: 'เช่น เลื่อนวันทำ, เปลี่ยนแผน, ราคาหรือเงื่อนไขไม่ตรง',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณาระบุเหตุผลที่เลิกจ้างก่อนยืนยัน'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('ยืนยันยกเลิกและส่งเหตุผล'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      reasonCtrl.dispose();
      return;
    }

    try {
      await _service.cancelBooking(
        bookingId: booking.id,
        reason: reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกการจ้างและส่งเหตุผลให้ช่างเรียบร้อยแล้ว'),
        ),
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      reasonCtrl.dispose();
    }
  }

  Future<void> _openReviewDialog(BookingModel booking) async {
    final jobNo = booking.jobNumber?.trim() ?? '';
    if (booking.status != 'completed' || jobNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รีวิวได้เฉพาะงานที่เสร็จสิ้นและมี Job Number เท่านั้น'),
        ),
      );
      return;
    }

    int rating = 5;
    final commentCtrl = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('รีวิวช่าง • Job: $jobNo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ให้คะแนนความพึงพอใจ (1 - 5 ดาว):'),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = star),
                    icon: Icon(
                      star <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ความคิดเห็นเพิ่มเติม',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ส่งรีวิว'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) {
      commentCtrl.dispose();
      return;
    }

    try {
      await _client.from('reviews').insert({
        'booking_id': booking.id,
        'job_number': jobNo,
        'customer_id': booking.customerId,
        'technician_id': booking.technicianId,
        'rating': rating,
        'comment': commentCtrl.text.trim(),
        'scheduled_at': booking.scheduledAt.toIso8601String(),
        'service_address': booking.serviceAddress,
        'job_description': booking.description,
        'booking_status': booking.status,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกรีวิวเรียบร้อยแล้ว'),
        ),
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งรีวิวไม่สำเร็จ: $e')),
      );
    } finally {
      commentCtrl.dispose();
    }
  }

  Future<void> _openComplaintDialog(BookingModel booking) async {
    final jobNo = booking.jobNumber?.trim() ?? '';
    final subjectCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    final uid = _client.auth.currentUser?.id ?? booking.customerId;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          jobNo.isNotEmpty
              ? 'ร้องเรียนการให้บริการ • Job: $jobNo'
              : 'ร้องเรียนการให้บริการ',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'หัวข้อที่ร้องเรียน',
                hintText: 'เช่น มาสาย, ทิ้งงาน, ราคาไม่ตรงตกลง',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'รายละเอียดข้อร้องเรียน',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (subjectCtrl.text.trim().isEmpty ||
                  detailsCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('กรุณากรอกหัวข้อและรายละเอียดข้อร้องเรียน'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('ส่งคำร้องเรียน'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      subjectCtrl.dispose();
      detailsCtrl.dispose();
      return;
    }

    try {
      final subjectText = subjectCtrl.text.trim();
      final detailsText = detailsCtrl.text.trim();
      final combinedReason = '$subjectText: $detailsText';

      await _client.from('complaints').insert({
        'booking_id': booking.id,
        'job_number': jobNo.isEmpty ? null : jobNo,
        'customer_id': uid,
        'technician_id': booking.technicianId,
        'subject': subjectText,
        'details': detailsText,
        'reason': combinedReason,
        'status': 'pending',
        'scheduled_at': booking.scheduledAt.toIso8601String(),
        'service_address': booking.serviceAddress,
        'job_description': booking.description,
        'booking_status': booking.status,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำร้องเรียนให้ผู้ดูแลระบบเรียบร้อยแล้ว'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ส่งคำร้องเรียนไม่สำเร็จ: $e')),
      );
    } finally {
      subjectCtrl.dispose();
      detailsCtrl.dispose();
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอช่างตอบรับ';
      case 'accepted':
        return 'ช่างรับงานแล้ว';
      case 'in_progress':
        return 'กำลังดำเนินงาน';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      case 'rejected':
        return 'ช่างปฏิเสธ';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} เวลา $hh:$mm น.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('การจองของฉัน'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text('ยังไม่มีรายการจอง'))
              : RefreshIndicator(
                  onRefresh: () => _loadBookings(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final b = _bookings[index];
                      final isPending = b.status == 'pending';
                      final isAccepted = b.status == 'accepted';
                      final canCancel =
                          b.status == 'pending' || b.status == 'accepted';
                      final hasJobNo =
                          b.jobNumber != null && b.jobNumber!.trim().isNotEmpty;
                      final alreadyReviewed = _reviewedBookingIds.contains(b.id);
                      final canReview =
                          b.status == 'completed' && hasJobNo && !alreadyReviewed;

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hasJobNo
                                        ? 'Job: ${b.jobNumber}'
                                        : 'รายการนัดหมาย',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7041D8),
                                    ),
                                  ),
                                  Chip(label: Text(_statusText(b.status))),
                                ],
                              ),
                              if (isPending || isAccepted) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? const Color(0xFFFFF8E1)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isPending
                                        ? 'สถานะ: รอช่างตอบรับ'
                                        : 'สถานะ: ช่างรับงานแล้ว',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isPending
                                          ? const Color(0xFF8D6E00)
                                          : const Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                              ],
                              _technicianProfileRow(b),
                              const SizedBox(height: 10),
                              Text(
                                'วันและเวลานัดหมาย: ${_formatDateTime(b.scheduledAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('ที่อยู่: ${b.serviceAddress ?? '-'}'),
                              const Divider(height: 20),
                              Text(b.description ?? 'ไม่มีรายละเอียด'),
                              if (canCancel) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _cancelBooking(b),
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text(
                                      'ยกเลิกการจ้าง & ส่งเหตุผลให้ช่าง',
                                    ),
                                  ),
                                ),
                              ],
                              if (canReview) ...[
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _openReviewDialog(b),
                                    icon: const Icon(Icons.star_rate),
                                    label: const Text('ให้ดาวและรีวิวช่าง'),
                                  ),
                                ),
                              ],
                              if (b.status == 'completed' && alreadyReviewed) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  '✓ รีวิวงานนี้แล้ว',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ],
                              if (b.status == 'completed') ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFC62828),
                                      side: const BorderSide(
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                    onPressed: () => _openComplaintDialog(b),
                                    icon: const Icon(
                                      Icons.report_problem_outlined,
                                    ),
                                    label: const Text('ร้องเรียน'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}