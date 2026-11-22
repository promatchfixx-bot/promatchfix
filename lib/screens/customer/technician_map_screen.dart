import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/technician_location_model.dart';
import '../../services/location_service.dart';

class TechnicianMapScreen extends StatefulWidget {
  const TechnicianMapScreen({super.key});

  @override
  State<TechnicianMapScreen> createState() => _TechnicianMapScreenState();
}

class _TechnicianMapScreenState extends State<TechnicianMapScreen> {
  final LocationService _service = LocationService();
  final MapController _mapController = MapController();

  List<TechnicianLocation> _locations = [];

  LatLng? _customerPosition;

  RealtimeChannel? _channel;
  Timer? _refreshTimer;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadLocations();

    _channel = _service.subscribeToLocations(() {
      _loadLocations();
    });

    // Recheck stale positions even if no new event arrives.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadLocations(),
    );

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      final result = await _service.getLiveLocations();

      if (!mounted) return;

      setState(() {
        _locations = result;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'โหลดตำแหน่งช่างไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  Future<void> _locateCustomer() async {
    try {
      final position = await _service.getCurrentPosition();

      if (position.accuracy > 50) {
        throw Exception('ตำแหน่งยังไม่แม่นยำพอ');
      }

      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() => _customerPosition = point);

      _mapController.move(point, 15);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center =
        _customerPosition ??
        (_locations.isNotEmpty
            ? LatLng(_locations.first.latitude, _locations.first.longitude)
            : const LatLng(13.7563, 100.5018));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ค้นหาช่างใกล้คุณ'),
        actions: [
          IconButton(
            onPressed: _loadLocations,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.promatchfix',
              ),
              MarkerLayer(
                markers: [
                  if (_customerPosition != null)
                    Marker(
                      point: _customerPosition!,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.my_location,
                        size: 34,
                        color: Colors.blue,
                      ),
                    ),
                  ..._locations
                      .where((item) => item.isFresh)
                      .map(
                        (item) => Marker(
                          point: LatLng(item.latitude, item.longitude),
                          width: 48,
                          height: 55,
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ช่างที่เปิดรับงาน',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('รหัสช่าง: ${item.technicianId}'),
                                      Text(
                                        'ความแม่นยำ GPS: '
                                        '${item.accuracy.toStringAsFixed(1)} เมตร',
                                      ),
                                      Text('อัปเดต: ${item.updatedAt}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.location_on,
                              size: 45,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: _locateCustomer,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'พบช่าง ${_locations.where((e) => e.isFresh).length} คน',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
