import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/location_service.dart';

class TechnicianLocationScreen extends StatefulWidget {
  const TechnicianLocationScreen({super.key});

  @override
  State<TechnicianLocationScreen> createState() =>
      _TechnicianLocationScreenState();
}

class _TechnicianLocationScreenState extends State<TechnicianLocationScreen> {
  final LocationService _service = LocationService();

  StreamSubscription<Position>? _positionSubscription;

  bool _online = false;
  bool _loading = false;
  String _message = 'ยังไม่ได้เปิดรับงาน';
  double? _accuracy;

  String _formatError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');

    if (raw.contains(
          'KYC, approval, account or subscription requirement not met',
        ) ||
        raw.contains('P0001')) {
      return 'ยังไม่ผ่านเงื่อนไขการเปิดรับงาน กรุณาตรวจสอบการยืนยันตัวตน (KYC), การอนุมัติบัญชี, ข้อมูลโปรไฟล์ หรือแพ็กเกจสมาชิก';
    }

    if (raw.startsWith('PostgrestException')) {
      return 'ไม่สามารถอัปเดตสถานะการรับงานได้ กรุณาลองใหม่อีกครั้ง';
    }

    return raw;
  }

  void _startPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = _service.positionStream().listen(
      (position) async {
        if (!mounted || !_online) return;

        if (position.accuracy > 50) {
          setState(() {
            _accuracy = position.accuracy;
            _message =
                'GPS คลาดเคลื่อน ${position.accuracy.toStringAsFixed(0)} เมตร กรุณารอสัญญาณ';
          });
          return;
        }

        try {
          await _service.updateLocation(position);
          if (mounted && _online) {
            setState(() {
              _accuracy = position.accuracy;
              _message = 'กำลังส่งตำแหน่งทุก 15 วินาที';
            });
          }
        } catch (_) {
          if (mounted && _online) {
            setState(() {
              _message = 'อัปเดตตำแหน่งไม่สำเร็จ';
            });
          }
        }
      },
      onError: (_) {
        if (mounted && _online) {
          setState(() {
            _message = 'เกิดปัญหาการอ่าน GPS';
          });
        }
      },
    );
  }

  Future<void> _turnOn() async {
    if (_loading || _online) return;

    setState(() {
      _loading = true;
      _message = 'กำลังตรวจสอบ GPS...';
    });

    try {
      await _service.startTracking(markOnline: true);
      final current = await _service.getCurrentPosition();
      _startPositionStream();

      if (!mounted) return;

      setState(() {
        _online = true;
        _accuracy = current.accuracy;
        _message = 'กำลังส่งตำแหน่งทุก 15 วินาที';
      });
    } catch (e) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      try {
        await _service.stopOnline();
      } catch (_) {}

      if (!mounted) return;

      final errText = _formatError(e);
      setState(() {
        _online = false;
        _accuracy = null;
        _message = errText;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errText)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _turnOff() async {
    if (_loading || !_online) return;

    setState(() {
      _loading = true;
      _message = 'กำลังปิดรับงาน...';
    });

    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      await _service.deleteMyLocation();
      await _service.stopOnline();

      if (!mounted) return;

      setState(() {
        _online = false;
        _accuracy = null;
        _message = 'ปิดรับงานและลบตำแหน่งแล้ว';
      });
    } catch (e) {
      if (!mounted) return;

      final errText = _formatError(e);
      setState(() {
        _message = errText;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errText)));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onToggleSwitch(bool value) async {
    if (value) {
      await _turnOn();
    } else {
      await _turnOff();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _service.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: const Text('จัดการตำแหน่งและการรับงาน'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                color: Colors.white,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        _online
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        size: 72,
                        color: _online ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _online ? 'กำลังเปิดรับงาน' : 'ปิดรับงาน',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_message, textAlign: TextAlign.center),
                      if (_accuracy != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'ความแม่นยำ GPS: ${_accuracy!.toStringAsFixed(1)} เมตร',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('สถานะเปิดรับงาน'),
                        value: _online,
                        onChanged: _loading ? null : _onToggleSwitch,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading || _online ? null : _turnOn,
                  icon: const Icon(Icons.location_searching),
                  label: const Text('เปิดรับงาน'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading || !_online ? null : _turnOff,
                  icon: const Icon(Icons.location_off),
                  label: const Text('ปิดรับงาน'),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 12),
              const Text(
                'หมายเหตุ: ต้องเปิด GPS และอนุญาตตำแหน่งก่อนเปิดรับงาน '
                '(ทำงานขณะเปิดแอปอยู่)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
