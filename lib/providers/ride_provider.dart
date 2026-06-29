import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_app_mock/models/ride_details.dart';
import 'package:ride_app_mock/services/ride_service.dart';

/// Google Maps API Key used for Directions API.
const _apiKey = 'AIzaSyBiA_0nQ8UDLzi6uJ444825ZOoCi_-SHBc';

/// [RideProvider] manages the business logic for calculating ride fares and
/// rendering path polylines on the map based on origin and destination.
class RideProvider with ChangeNotifier {
  final RideService _rideService = RideService();

  // Internal state for ride result details and status.
  RideDetails? _rideDetails;
  bool _isLoading = false;
  String? _error;

  // Internal state for Route/Map visualization.
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  GoogleMapController? _mapController;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  String _pickupText = '';
  String _dropText = '';

  // Getters for external UI access.
  RideDetails? get rideDetails => _rideDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<Polyline> get polylines => _polylines;
  bool get isLoadingRoute => _isLoadingRoute;
  LatLng? get pickupLatLng => _pickupLatLng;
  LatLng? get dropLatLng => _dropLatLng;
  String get pickupText => _pickupText;
  String get dropText => _dropText;

  /// Fetches available ride fare details from the service based on address text.
  Future<void> findRide(String pickup, String drop) async {
    if (pickup.isEmpty || drop.isEmpty) {
      _error = "Please enter both pickup and drop locations";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _rideDetails = null;
    _error = null;
    notifyListeners();

    try {
      _rideDetails = await _rideService.fetchRideFare(pickup, drop);
    } catch (e) {
      _error = "Failed to find a ride. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Assigns the map controller and fits the map view to show both points.
  void setMapController(GoogleMapController c) {
    _mapController = c;
    if (!_isLoadingRoute) _fitBounds();
  }

  /// Sets the route coordinates and human-readable names, then triggers route fetching.
  void setRoute(LatLng pickup, LatLng drop, String pickupText, String dropText) {
    _pickupLatLng = pickup;
    _dropLatLng = drop;
    _pickupText = pickupText;
    _dropText = dropText;
    fetchRoute(pickup, drop);
  }

  /// Fetches the overview polyline from Google Directions API to draw the route.
  Future<void> fetchRoute(LatLng pickup, LatLng drop) async {
    _isLoadingRoute = true;
    _polylines = {};
    notifyListeners();

    final origin = '${pickup.latitude},${pickup.longitude}';
    final destination = '${drop.latitude},${drop.longitude}';
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$origin&destination=$destination&key=$_apiKey',
    );

    debugPrint('[Route] GET $uri');
    try {
      final response = await http.get(uri);
      debugPrint('[Route] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          // Parse the encoded polyline string from the API response.
          final encoded =
              data['routes'][0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF5C2D91),
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
      debugPrint('[Route] Error: $e');
    }

    // Fallback: draw a dashed straight line between the two points if API fails.
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [pickup, drop],
        color: const Color(0xFF5C2D91),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
    _isLoadingRoute = false;
    notifyListeners();
    _fitBounds();
  }

  /// Adjusts map zoom and center to perfectly fit both the pickup and destination points.
  void _fitBounds() {
    // If the map or coordinates aren't ready, we can't calculate the frame.
    if (_mapController == null || _pickupLatLng == null || _dropLatLng == null) return;

    final pickup = _pickupLatLng!;
    final drop = _dropLatLng!;

    // Calculate the South-West corner (minimum latitude and minimum longitude).
    final sw = LatLng(
      pickup.latitude < drop.latitude ? pickup.latitude : drop.latitude,
      pickup.longitude < drop.longitude ? pickup.longitude : drop.longitude,
    );

    // Calculate the North-East corner (maximum latitude and maximum longitude).
    final ne = LatLng(
      pickup.latitude > drop.latitude ? pickup.latitude : drop.latitude,
      pickup.longitude > drop.longitude ? pickup.longitude : drop.longitude,
    );

    // Create a bounding box and animate the camera to fit that box with 80px padding.
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  /// Decompresses the encoded Google Maps polyline string into a list of LatLng points.
  /// This uses a bitwise algorithm defined by Google to compress coordinate lists.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      // Step 1: Decode the latitude delta.
      do {
        // ASCII value - 63 is the base for Google's polyline encoding.
        b = encoded.codeUnitAt(index++) - 63;
        // Use bitwise OR and Shift to reconstruct the number from 5-bit chunks.
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20); // If the byte is >= 0x20, another chunk follows.

      // Convert the zigzag-encoded value back to a signed integer.
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat; // Coordinates in polylines are stored as relative offsets.

      // Step 2: Decode the longitude delta (same logic as latitude).
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // Convert the integer (multiplied by 1e5 in the string) back to a double coordinate.
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Clears map-specific route data.
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

  /// Resets fare details and loading flags.
  void reset() {
    _rideDetails = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
