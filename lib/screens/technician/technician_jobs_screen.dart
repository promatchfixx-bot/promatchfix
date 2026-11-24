import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../services/booking_service.dart';
import '../../services/job_board_service.dart';

class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({super.key});

  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  final BookingService service = BookingService();
  final JobBoardService _jobBoardService = JobBoardService();
  final SupabaseClient _client = Supabase.instance.client;

  DateTime? selectedDate;
  String weekScope = 'this_week'; // 'this_week' | 'all' | 'specific_date'

  bool loading = true;
  bool _autoAdvancing = false;
  String filter = 'all';

  var bookings = [];
  var feedbackByBookingId = {};
  var extraFeedbacks = [];
  var reviewByBookingId = {};
  var reviewByJobNumber = {};
  Map<String, Map<String, dynamic>> customerProfilesById = {};
  Timer? _autoStartTimer;

  @override
  void initState() {
    super.initState();
    loadBookings();
    _autoStartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _autoStartDueBookings();
    });
  }

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    super.dispose();
  }

  int _statusSortPriority(String status) {
    switch (status) {
      case 'pending':
        return 0; // บนสุด: รอตอบรับ
      case 'accepted':
        return 1; // ถัดลงมา: รับงานแล้ว
      case 'in_progress':
        return 2; // ถัดลงมา: กำลังดำเนินงาน
      case 'completed':
        return 3; // เสร็จสิ้น: ดันลงไปอยู่ล่างสุด
      case 'cancelled':
      case 'rejected':
        return 4;
      default:
        return 2;
    }
  }

  int _compareBookings(BookingModel a, BookingModel b) {
    final pa = _statusSortPriority(a.status);
    final pb = _statusSortPriority(b.status);
    if (pa != pb) return pa.compareTo(pb);
    return a.scheduledAt.compareTo(b.scheduledAt);
  }

  Future<void> _autoStartDueBookings() async {
    if (_autoAdvancing || bookings.isEmpty) return;
    final now = DateTime.now();
    final dueBookings = bookings.where((item) {
      final b = item as BookingModel;
      return b.status == 'accepted' && !b.scheduledAt.toLocal().isAfter(now);
    }).toList();

    if (dueBookings.isEmpty) return;

    _autoAdvancing = true;
    try {
      for (final item in dueBookings) {
        final b = item as BookingModel;
        try {
          await service.updateBookingStatus(
            bookingId: b.id,
            status: 'in_progress',
          );
        } catch (_) {}
      }
      if (!mounted) return;
      await loadBookings(showSpinner: false);
    } finally {
      _autoAdvancing = false;
    }
  }

  Future<void> _loadCustomerProfiles(List bookingList, List extras) async {
    final map = <String, Map<String, dynamic>>{};
    final ids = <String>{};

    for (final item in bookingList) {
      final b = item as BookingModel;
      final cid = b.customerId.trim();
      if (cid.isNotEmpty) ids.add(cid);
    }

    for (final item in extras) {
      if (item is! Map) continue;
      for (final key in const ['customer_id', 'user_id']) {
        final cid = item[key]?.toString().trim() ?? '';
        if (cid.isNotEmpty) ids.add(cid);
      }
      final jobMap = item['job_posts'];
      if (jobMap is Map) {
        final cid = jobMap['customer_id']?.toString().trim() ?? '';
        if (cid.isNotEmpty) ids.add(cid);
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

    customerProfilesById = map;
  }

  Widget _customerAvatarNameRow({
    required String? customerId,
    required String? fallbackName,
    String? phone,
  }) {
    final cleanId = (customerId ?? '').trim();
    final profile = cleanId.isNotEmpty ? customerProfilesById[cleanId] : null;
    final profileName = profile?['full_name']?.toString().trim() ?? '';
    final displayName = profileName.isNotEmpty
        ? profileName
        : ((fallbackName ?? '').trim().isNotEmpty
            ? fallbackName!.trim()
            : '-');
    final avatarUrl = profile?['avatar_url']?.toString().trim() ?? '';
    final hasAvatar = avatarUrl.isNotEmpty;
    final displayPhone = (phone ?? '').trim().isNotEmpty
        ? phone!.trim()
        : (profile?['phone']?.toString().trim() ?? '-');

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEDE7FF),
          backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
          child: !hasAvatar
              ? const Icon(
                  Icons.person,
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
                'ลูกค้า: $displayName',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'โทรศัพท์: $displayPhone',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> loadBookings({bool showSpinner = true}) async {
    if (showSpinner && mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await service.getTechnicianBookings(date: null);
      final feedbacks = await _jobBoardService.getMyCancellationFeedbacks();

      final byBooking = {};
      final bookingIdsInList = List.from(result)
          .map((item) => (item as BookingModel).id)
          .toSet();
      final extras = [];

      for (final item in List.from(feedbacks)) {
        final fb = item as Map;
        final bId = fb['booking_id']?.toString() ?? '';
        final reason = fb['reason']?.toString().trim() ?? '';
        if (bId.isNotEmpty && reason.isNotEmpty) {
          byBooking[bId] = reason;
        }
        if (bId.isEmpty || !bookingIdsInList.contains(bId)) {
          extras.add(fb);
        }
      }

      final byReviewBooking = {};
      final byReviewJobNo = {};
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        try {
          final reviewRows = await _client
              .from('reviews')
              .select('*')
              .eq('technician_id', uid)
              .order('created_at', ascending: false);

          for (final item in List.from(reviewRows)) {
            final r = item as Map;
            final bId = r['booking_id']?.toString() ?? '';
            final jobNo = r['job_number']?.toString().trim() ?? '';
            if (bId.isNotEmpty && byReviewBooking[bId] == null) {
              byReviewBooking[bId] = r;
            }
            if (jobNo.isNotEmpty && byReviewJobNo[jobNo] == null) {
              byReviewJobNo[jobNo] = r;
            }
          }
        } catch (_) {}
      }

      final sorted = List.from(result)
        ..sort(
          (a, b) => _compareBookings(a as BookingModel, b as BookingModel),
        );

      await _loadCustomerProfiles(sorted, extras);

      if (!mounted) return;

      setState(() {
        bookings = sorted;
        feedbackByBookingId = byBooking;
        extraFeedbacks = extras;
        reviewByBookingId = byReviewBooking;
        reviewByJobNumber = byReviewJobNo;
        loading = false;
      });

      await _autoStartDueBookings();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('โหลดคิวงานไม่สำเร็จ: $e')));
    }
  }

  bool _isInCurrentWeek(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final endOfWeekExclusive = startOfWeek.add(const Duration(days: 7));
    return !local.isBefore(startOfWeek) && local.isBefore(endOfWeekExclusive);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  List get filteredBookings {
    final list = bookings.where((item) {
      final booking = item as BookingModel;
      final matchesScope = switch (weekScope) {
        'this_week' => _isInCurrentWeek(booking.scheduledAt),
        'specific_date' => selectedDate == null
            ? true
            : _isSameDay(booking.scheduledAt, selectedDate!),
        _ => true,
      };
      if (!matchesScope) return false;
      if (filter == 'all') return true;
      return booking.status == filter;
    }).toList();

    list.sort(
      (a, b) => _compareBookings(a as BookingModel, b as BookingModel),
    );
    return list;
  }

  String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'รอตอบรับ';
      case 'accepted':
        return 'รับงานแล้ว';
      case 'rejected':
        return 'ปฏิเสธ';
      case 'in_progress':
        return 'กำลังดำเนินงาน';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      default:
        return status;
    }
  }

  String _formatThaiSchedule(DateTime dt) {
    final local = dt.toLocal();
    const weekdays = [
      'วันจันทร์',
      'วันอังคาร',
      'วันพุธ',
      'วันพฤหัสบดี',
      'วันศุกร์',
      'วันเสาร์',
      'วันอาทิตย์',
    ];
    final wd = weekdays[(local.weekday - 1).clamp(0, 6)];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$wd ${local.day}/${local.month}/${local.year} เวลา $hh:$mm น.';
  }

  Future<void> respond(BookingModel booking, bool accept) async {
    try {
      await service.respondToBooking(bookingId: booking.id, accept: accept);

      await loadBookings();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'รับงานเรียบร้อยแล้ว สามารถเริ่มดำเนินงานได้' : 'ปฏิเสธงานแล้ว',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> changeStatus(BookingModel booking, String status) async {
    try {
      await service.updateBookingStatus(bookingId: booking.id, status: status);

      await loadBookings();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        weekScope = 'specific_date';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredBookings;
    final showExtraCancelled = filter == 'all' || filter == 'cancelled';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('คิวงานของฉัน'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: loadBookings, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('สัปดาห์นี้'),
                      selected: weekScope == 'this_week',
                      onSelected: (_) {
                        setState(() => weekScope = 'this_week');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('ทุกวัน'),
                      selected: weekScope == 'all',
                      onSelected: (_) {
                        setState(() => weekScope = 'all');
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        weekScope == 'specific_date' && selectedDate != null
                            ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                            : 'เลือกวัน',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'เรียงงานรอตอบรับไว้บนสุด ไล่ลงมา และดันงานที่เสร็จสิ้นลงล่างสุด',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton('all', 'ทั้งหมด'),
                _filterButton('pending', 'รอตอบรับ'),
                _filterButton('accepted', 'รับงานแล้ว'),
                _filterButton('in_progress', 'กำลังทำ'),
                _filterButton('completed', 'เสร็จแล้ว'),
                _filterButton('cancelled', 'ยกเลิกแล้ว'),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (items.isEmpty &&
                      (!showExtraCancelled || extraFeedbacks.isEmpty))
                    ? const Center(child: Text('ไม่มีคิวงานตามตัวกรองนี้'))
                    : RefreshIndicator(
                        onRefresh: loadBookings,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ...items.map(
                              (item) => _bookingCard(item as BookingModel),
                            ),
                            if (showExtraCancelled)
                              ...extraFeedbacks.map((item) {
                                final fb = item as Map;
                                final jobMap = fb['job_posts'] as Map?;
                                final cid = fb['customer_id']?.toString() ??
                                    jobMap?['customer_id']?.toString() ??
                                    fb['user_id']?.toString();
                                return Card(
                                  color: Colors.red.shade50,
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                jobMap?['title']?.toString() ??
                                                    'งานที่ถูกยกเลิกจ้าง',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const Chip(label: Text('ยกเลิกแล้ว')),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _customerAvatarNameRow(
                                          customerId: cid,
                                          fallbackName:
                                              jobMap?['customer_name']?.toString(),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'เหตุผลจากลูกค้า: ${fb['reason'] ?? '-'}',
                                          style: TextStyle(
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: filter == value,
        onSelected: (_) {
          setState(() => filter = value);
        },
      ),
    );
  }

  Widget _bookingCard(BookingModel booking) {
    final reason = feedbackByBookingId[booking.id]?.toString();
    final jobNo = booking.jobNumber?.trim() ?? '';
    final reviewMap = (reviewByBookingId[booking.id] ??
        (jobNo.isNotEmpty ? reviewByJobNumber[jobNo] : null)) as Map?;

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'รายการนัดหมาย',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Chip(label: Text(statusLabel(booking.status))),
              ],
            ),
            if (booking.jobNumber != null)
              Text(
                'Job: ${booking.jobNumber}',
                style: const TextStyle(
                  color: Color(0xFF7041D8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2EEFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 18,
                    color: Color(0xFF7041D8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'วันที่ต้องทำ: ${_formatThaiSchedule(booking.scheduledAt)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A25A8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _customerAvatarNameRow(
              customerId: booking.customerId,
              fallbackName: booking.customerName,
              phone: booking.customerPhone,
            ),
            const SizedBox(height: 6),
            Text('สถานที่: ${booking.serviceAddress ?? '-'}'),
            const Divider(height: 24),
            Text(booking.description ?? 'ไม่มีรายละเอียด'),
            if (reviewMap != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รีวิวจากลูกค้า (${jobNo.isNotEmpty ? jobNo : (reviewMap['job_number'] ?? '-')}) • ${reviewMap['rating'] ?? 5}/5 ดาว',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    if ((reviewMap['comment']?.toString().trim() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('ความเห็น: ${reviewMap['comment']}'),
                    ],
                  ],
                ),
              ),
            ],
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'เหตุผลที่ลูกค้ายกเลิก: $reason',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (booking.status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => respond(booking, false),
                      child: const Text('ปฏิเสธ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => respond(booking, true),
                      child: const Text('รับงาน'),
                    ),
                  ),
                ],
              ),
            if (booking.status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => changeStatus(booking, 'in_progress'),
                  child: const Text('เริ่มดำเนินงาน'),
                ),
              ),
            if (booking.status == 'in_progress')
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => changeStatus(booking, 'completed'),
                  child: const Text('ปิดงาน / เสร็จสิ้น'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}