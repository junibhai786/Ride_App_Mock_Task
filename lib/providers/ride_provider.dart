import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';
import 'package:ride_app_mock/models/ride_details.dart';
import 'package:ride_app_mock/services/ride_service.dart';

class RideProvider with ChangeNotifier {
  final RideService _rideService = RideService();

  // ── Fare state ─────────────────────────────────────────────────────────────

  RideDetails? _rideDetails;
  bool _isLoading = false;
  AppException? _exception;

  // ── Route / map state ──────────────────────────────────────────────────────

  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  String _pickupText = '';
  String _dropText = '';

  // ── Getters ────────────────────────────────────────────────────────────────

  RideDetails? get rideDetails => _rideDetails;
  bool get isLoading => _isLoading;
  AppException? get exception => _exception;
  Set<Polyline> get polylines => _polylines;
  bool get isLoadingRoute => _isLoadingRoute;
  LatLng? get pickupLatLng => _pickupLatLng;
  LatLng? get dropLatLng => _dropLatLng;
  String get pickupText => _pickupText;
  String get dropText => _dropText;

  // ── Fare lookup ────────────────────────────────────────────────────────────

  Future<void> findRide(String pickup, String drop) async {
    if (pickup.isEmpty || drop.isEmpty) {
      _exception = const ValidationException(
          'Please enter both pickup and drop locations.');
      notifyListeners();
      return;
    }

    _isLoading = true;
    _rideDetails = null;
    _exception = null;
    notifyListeners();

    try {
      _rideDetails = await _rideService.fetchRideFare(pickup, drop);
    } on AppException catch (e) {
      _exception = e;
    } catch (_) {
      _exception = const UnknownException('Failed to find a ride. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Route management ───────────────────────────────────────────────────────

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_isLoadingRoute) _fitBounds();
  }

  void setRoute(
    LatLng pickup,
    LatLng drop,
    String pickupText,
    String dropText,
  ) {
    _pickupLatLng = pickup;
    _dropLatLng = drop;
    _pickupText = pickupText;
    _dropText = dropText;
    fetchRoute(pickup, drop);
  }

  Future<void> fetchRoute(LatLng pickup, LatLng drop) async {
    _isLoadingRoute = true;
    _polylines = {};
    notifyListeners();

    final origin = '${pickup.latitude},${pickup.longitude}';
    final destination = '${drop.latitude},${drop.longitude}';
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination&key=${AppConstants.googleMapsApiKey}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final encoded =
              data['routes'][0]['overview_polyline']['points'] as String;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _decodePolyline(encoded),
              color: AppColors.primary,
              width: 5,
            ),
          };
          _isLoadingRoute = false;
          notifyListeners();
          _fitBounds();
          return;
        }
        debugPrint('[Route] Directions API status: ${data['status']}');
      }
    } catch (e) {
      debugPrint('[Route] fetchRoute error: $e');
    }

    // Fallback: straight dashed line.
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [pickup, drop],
        color: AppColors.primary,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
    _isLoadingRoute = false;
    notifyListeners();
    _fitBounds();
  }

  void _fitBounds() {
    if (_mapController == null ||
        _pickupLatLng == null ||
        _dropLatLng == null) {
      return;
    }

    final pickup = _pickupLatLng!;
    final drop = _dropLatLng!;

    final sw = LatLng(
      pickup.latitude < drop.latitude ? pickup.latitude : drop.latitude,
      pickup.longitude < drop.longitude ? pickup.longitude : drop.longitude,
    );
    final ne = LatLng(
      pickup.latitude > drop.latitude ? pickup.latitude : drop.latitude,
      pickup.longitude > drop.longitude ? pickup.longitude : drop.longitude,
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  void resetRoute() {
    _polylines = {};
    _isLoadingRoute = false;
    _mapController = null;
    _pickupLatLng = null;
    _dropLatLng = null;
    _pickupText = '';
    _dropText = '';
    notifyListeners();
  }

  void reset() {
    _rideDetails = null;
    _isLoading = false;
    _exception = null;
    notifyListeners();
  }
}
