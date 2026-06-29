import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';

class RideRequestProvider with ChangeNotifier {
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────

  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  List<dynamic> _pickupSuggestions = [];
  List<dynamic> _dropSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDropSuggestions = false;
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  Timer? _debounce;

  // ── Getters ────────────────────────────────────────────────────────────────

  LatLng? get pickupLatLng => _pickupLatLng;
  LatLng? get dropLatLng => _dropLatLng;
  List<dynamic> get pickupSuggestions => _pickupSuggestions;
  List<dynamic> get dropSuggestions => _dropSuggestions;
  bool get showPickupSuggestions => _showPickupSuggestions;
  bool get showDropSuggestions => _showDropSuggestions;
  Set<Marker> get markers => _markers;

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  // ── Input handlers ─────────────────────────────────────────────────────────

  void onPickupChanged(String value) {
    _debounce?.cancel();
    _pickupLatLng = null;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      _pickupSuggestions = suggestions;
      _showPickupSuggestions = suggestions.isNotEmpty;
      notifyListeners();
    });
  }

  void onDropChanged(String value) {
    _debounce?.cancel();
    _dropLatLng = null;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      _dropSuggestions = suggestions;
      _showDropSuggestions = suggestions.isNotEmpty;
      notifyListeners();
    });
  }

  // ── Location selection ─────────────────────────────────────────────────────

  Future<void> selectPickup(dynamic prediction) async {
    final description = prediction['description'] as String;
    final placeId = prediction['place_id'] as String;

    pickupController.text = description;
    _showPickupSuggestions = false;
    _pickupSuggestions = [];
    notifyListeners();

    final latLng = await _fetchLatLng(placeId);
    if (latLng != null) {
      _pickupLatLng = latLng;
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'pickup'),
        Marker(
          markerId: const MarkerId('pickup'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup', snippet: description),
        ),
      };
      notifyListeners();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  Future<void> selectDrop(dynamic prediction) async {
    final description = prediction['description'] as String;
    final placeId = prediction['place_id'] as String;

    dropController.text = description;
    _showDropSuggestions = false;
    _dropSuggestions = [];
    notifyListeners();

    final latLng = await _fetchLatLng(placeId);
    if (latLng != null) {
      _dropLatLng = latLng;
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'drop'),
        Marker(
          markerId: const MarkerId('drop'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Drop', snippet: description),
        ),
      };
      notifyListeners();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  void showPickupSuggestionList() {
    if (_pickupSuggestions.isNotEmpty) {
      _showPickupSuggestions = true;
      notifyListeners();
    }
  }

  void showDropSuggestionList() {
    if (_dropSuggestions.isNotEmpty) {
      _showDropSuggestions = true;
      notifyListeners();
    }
  }

  // ── Google Places API ──────────────────────────────────────────────────────

  Future<List<dynamic>> _fetchSuggestions(String input) async {
    if (input.isEmpty) return [];

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=${AppConstants.googleMapsApiKey}'
        '&components=country:pk',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          return data['predictions'] as List<dynamic>;
        }
        debugPrint('[Places] Autocomplete status: ${data['status']}');
      } else {
        throw ServerException(
          'Places API returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on AppException catch (e) {
      debugPrint('[Places] Autocomplete error: $e');
    } catch (e) {
      debugPrint('[Places] Autocomplete unexpected error: $e');
    }

    return [];
  }

  Future<LatLng?> _fetchLatLng(String placeId) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=${AppConstants.googleMapsApiKey}',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
        debugPrint('[Places] Details status: ${data['status']}');
      } else {
        throw ServerException(
          'Places Details API returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on AppException catch (e) {
      debugPrint('[Places] Details error: $e');
    } catch (e) {
      debugPrint('[Places] Details unexpected error: $e');
    }

    return null;
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    pickupController.dispose();
    dropController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
