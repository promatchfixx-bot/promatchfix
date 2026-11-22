import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/technician_location_model.dart';

class LocationService {
  final SupabaseClient _client = Supabase.instance.client;

  Timer? _timer;
  bool _sending = false;

  Future<void> setOnline(bool online) async {
    await _client.rpc('set_my_technician_online', params: {'p_online': online});
  }

  Future<bool> checkPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      throw Exception('กรุณาเปิด GPS ในโทรศัพท์');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('กรุณาเปิดสิทธิ์ Location ในการตั้งค่าอุปกรณ์');
    }

    return true;
  }

  Future<Position> getCurrentPosition() async {
    await checkPermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    if (position.accuracy > 50) {
      throw Exception(
        'GPS คลาดเคลื่อน ${position.accuracy.toStringAsFixed(0)} เมตร กรุณารอสัญญาณ',
      );
    }

    return position;
  }

  Future<void> updateLocation(Position position) async {
    if (position.accuracy > 50) {
      throw Exception(
        'GPS คลาดเคลื่อน ${position.accuracy.toStringAsFixed(0)} เมตร กรุณารอสัญญาณ',
      );
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบ');
    }

    await _client.rpc(
      'update_my_technician_location',
      params: {
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_accuracy': position.accuracy,
      },
    );
  }

  Future<void> sendLocation() async {
    if (_sending) return;

    _sending = true;

    try {
      final position = await getCurrentPosition();
      await updateLocation(position);
    } finally {
      _sending = false;
    }
  }

  Future<void> startTracking({bool markOnline = true}) async {
    await stopTracking();

    if (markOnline) {
      await setOnline(true);
    }

    await sendLocation();

    _timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        await sendLocation();
      } catch (e) {
        debugPrint('Location update failed: $e');
      }
    });
  }

  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> stopOnline() async {
    await stopTracking();
    await setOnline(false);
  }

  Future<void> deleteMyLocation() async {
    final user = _client.auth.currentUser;

    await stopTracking();

    if (user == null) return;

    await _client
        .from('technician_live_locations')
        .delete()
        .eq('technician_id', user.id);
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    );
  }

  Future<List<TechnicianLocation>> getLiveLocations() async {
    final result = await _client
        .from('technician_live_locations')
        .select('technician_id, latitude, longitude, accuracy_m, updated_at');

    return (result as List)
        .map(
          (item) =>
              TechnicianLocation.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.isFresh)
        .toList();
  }

  RealtimeChannel subscribeToLocations(void Function() onChanged) {
    final channel = _client.channel('technician-live-map');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'technician_live_locations',
          callback: (_) => onChanged(),
        )
        .subscribe();

    return channel;
  }
}
