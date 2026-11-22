import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;

import '../../services/subscription_service.dart';
import '../../models/subscription_model.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final service = SubscriptionService();

  TechnicianSubscription? subscription;
  String? qrUrl;
  String? qrBase64;
  Uint8List? qrBytes;
  bool isSvgQr = false;
  String? svgViewType;
  String? paymentId;
  bool loading = true;
  bool creating = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final result = await service.getCurrentSubscription();

      if (!mounted) return;

      setState(() {
        subscription = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _registerSvgView(String cleanBase64, String id) {
    final viewType =
        'promptpay-qr-svg-$id-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = 'data:image/svg+xml;base64,$cleanBase64'
        ..style.width = '240px'
        ..style.height = '240px'
        ..style.objectFit = 'contain'
        ..alt = 'PromptPay QR Code';
      return img;
    });
    return viewType;
  }

  Future<void> createPayment() async {
    setState(() => creating = true);

    try {
      final result = await service.createPayment();
      final rawBase64 = result['qr_base64']?.toString();
      final cleanBase64 = rawBase64?.replaceAll(RegExp(r'\s+'), '');

      Uint8List? decodedBytes;
      bool detectedSvg = false;
      String? registeredView;

      if (cleanBase64 != null && cleanBase64.isNotEmpty) {
        decodedBytes = base64Decode(cleanBase64);
        final headText = String.fromCharCodes(decodedBytes.take(120))
            .trimLeft();
        detectedSvg =
            headText.startsWith('<svg') || headText.startsWith('<?xml');

        if (kIsWeb && detectedSvg) {
          final payId = result['payment_id']?.toString() ?? 'qr';
          registeredView = _registerSvgView(cleanBase64, payId);
        }
      }

      if (!mounted) return;

      setState(() {
        qrUrl = result['qr_image_url']?.toString();
        qrBase64 = cleanBase64;
        qrBytes = decodedBytes;
        isSvgQr = detectedSvg;
        svgViewType = registeredView;
        paymentId = result['payment_id']?.toString();
        creating = false;
      });

      if ((qrBytes == null || qrBytes!.isEmpty) &&
          (qrUrl == null || qrUrl!.isEmpty)) {
        throw Exception('ไม่พบ QR Code');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => creating = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('สร้าง QR ไม่สำเร็จ: $e')));
    }
  }

  String dateText(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget buildQrWidget() {
    if (qrBytes != null && qrBytes!.isNotEmpty) {
      if (kIsWeb && isSvgQr && svgViewType != null) {
        return SizedBox(
          width: 240,
          height: 240,
          child: HtmlElementView(viewType: svgViewType!),
        );
      }

      return Image.memory(
        qrBytes!,
        height: 240,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('ไม่สามารถโหลด QR ได้'),
      );
    }

    if (!kIsWeb && qrUrl != null && qrUrl!.isNotEmpty) {
      return Image.network(
        qrUrl!,
        height: 240,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('ไม่สามารถโหลด QR ได้'),
      );
    }

    return const Text('ไม่สามารถโหลด QR ได้');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final active = subscription?.isActive ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('สมาชิกช่าง'),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF7041D8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'แพ็กเกจช่างรายเดือน',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '250 บาท / 30 วัน',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'เพิ่มโอกาสให้ลูกค้าค้นพบและติดต่อคุณ',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สถานะสมาชิก',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          active ? Icons.check_circle : Icons.info_outline,
                          color: active ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          active
                              ? 'สมาชิกใช้งานอยู่'
                              : 'ยังไม่มีสมาชิกที่ใช้งานอยู่',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('วันเริ่มต้น: ${dateText(subscription?.startsAt)}'),
                    Text('วันหมดอายุ: ${dateText(subscription?.expiresAt)}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (qrBytes != null || qrUrl != null) ...[
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'สแกนเพื่อชำระเงิน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildQrWidget(),
                      const SizedBox(height: 12),
                      const Text(
                        '250.00 บาท',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payment ID: ${paymentId ?? '-'}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'หลังชำระเงินแล้ว กดตรวจสอบสถานะอีกครั้ง',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (!active)
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: creating ? null : createPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7041D8),
                  ),
                  child: Text(
                    creating ? 'กำลังสร้างรายการ...' : 'สมัครสมาชิกและชำระเงิน',
                  ),
                ),
              ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ตรวจสอบสถานะสมาชิก'),
            ),

            const SizedBox(height: 12),
            const Text(
              'หมายเหตุ: ระบบจะเปิดสิทธิ์สมาชิกหลังได้รับการยืนยันจากผู้ให้บริการชำระเงินเท่านั้น',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
