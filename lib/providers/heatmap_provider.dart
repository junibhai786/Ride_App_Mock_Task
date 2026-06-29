import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';
import 'package:ride_app_mock/core/network/api_client.dart';

class HeatmapProvider with ChangeNotifier {
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  bool _isSeedLoading = false;
  AppException? _exception;

  int _highCount = 0;
  int _mediumCount = 0;
  int _lowCount = 0;
  bool _hasSurge = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get zones => _zones;
  bool get isLoading => _isLoading;
  bool get isSeedLoading => _isSeedLoading;
  AppException? get exception => _exception;
  int get highCount => _highCount;
  int get mediumCount => _mediumCount;
  int get lowCount => _lowCount;
  bool get hasSurge => _hasSurge;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  void init() {
    fetchZones();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => fetchZones(),
    );
  }

  void cleanup() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ── Data fetching ────────────────────────────────────────────────────────────

  Future<void> fetchZones() async {
    try {
      final body =
          await ApiClient.get('${AppConstants.serverUrl}/api/heatmap/data');

      if (body['success'] == true) {
        final zones = (body['data'] as List).cast<Map<String, dynamic>>();

        int high = 0, medium = 0, low = 0;
        bool surge = false;

        for (final z in zones) {
          switch (z['demandLevel'] as String) {
            case 'high':
              high++;
            case 'medium':
              medium++;
            default:
              low++;
          }
          if ((z['surgeMultiplier'] as num) > 1.0) surge = true;
        }

        _zones = zones;
        _highCount = high;
        _mediumCount = medium;
        _lowCount = low;
        _hasSurge = surge;
        _isLoading = false;
        _exception = null;
        notifyListeners();
      } else {
        throw ServerException(
          body['message'] as String? ??
              'Server returned an error. Is the backend running?',
          statusCode: 200,
        );
      }
    } on AppException catch (e) {
      debugPrint('[Heatmap] fetchZones error: $e');
      _isLoading = false;
      _exception = e;
      notifyListeners();
    }
  }

  Future<void> seedData() async {
    _isSeedLoading = true;
    notifyListeners();
    try {
      await ApiClient.post(
        '${AppConstants.serverUrl}/api/heatmap/seed'
        '?lat=31.5204&lng=74.3587&count=500',
      );
      await fetchZones();
    } on AppException catch (e) {
      debugPrint('[Heatmap] seedData error: $e');
    } finally {
      _isSeedLoading = false;
      notifyListeners();
    }
  }

  // ── Map data ─────────────────────────────────────────────────────────────────

  Set<Circle> buildCircles() {
    return _zones.asMap().entries.map((entry) {
      final idx = entry.key;
      final zone = entry.value;
      final lat = (zone['lat'] as num).toDouble();
      final lng = (zone['lng'] as num).toDouble();
      final level = zone['demandLevel'] as String;

      Color fill, stroke;
      switch (level) {
        case 'high':
          fill = const Color(0x78FF3232);
          stroke = const Color(0xBBFF3232);
        case 'medium':
          fill = const Color(0x78FF9800);
          stroke = const Color(0xBBFF9800);
        default:
          fill = const Color(0x6050C878);
          stroke = const Color(0x9050C878);
      }

      return Circle(
        circleId: CircleId('z$idx'),
        center: LatLng(lat, lng),
        radius: 800,
        fillColor: fill,
        strokeColor: stroke,
        strokeWidth: 1,
      );
    }).toSet();
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
