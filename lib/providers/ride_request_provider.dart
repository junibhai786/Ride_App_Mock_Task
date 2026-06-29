import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Google Maps API Key used for Autocomplete and Place Details.
const _apiKey = 'AIzaSyBiA_0nQ8UDLzi6uJ444825ZOoCi_-SHBc';

/// [RideRequestProvider] manages the state of location selection for a ride.
/// It handles text inputs, place suggestions via Google Maps API, and map markers.
class RideRequestProvider with ChangeNotifier {
  // Controllers for the pickup and drop-off text input fields.
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropController = TextEditingController();

  // Internal state variables for coordinates and UI behavior.
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  List<dynamic> _pickupSuggestions = [];
  List<dynamic> _dropSuggestions = [];
  bool _showPickupSuggestions = false;
  bool _showDropSuggestions = false;
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  Timer? _debounce;

  // Public Getters for state variables.
  LatLng? get pickupLatLng => _pickupLatLng;
  LatLng? get dropLatLng => _dropLatLng;
  List<dynamic> get pickupSuggestions => _pickupSuggestions;
  List<dynamic> get dropSuggestions => _dropSuggestions;
  bool get showPickupSuggestions => _showPickupSuggestions;
  bool get showDropSuggestions => _showDropSuggestions;
  Set<Marker> get markers => _markers;

  /// Sets the [GoogleMapController] once the map is initialized on the UI.
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Triggered when the text in the pickup field changes.
  /// Implements debouncing to limit API calls during typing.
  void onPickupChanged(String value) {
    // Stop and discard the previous timer if it exists.
    // This prevents the API call from firing if the user types another character within 400ms.
    _debounce?.cancel();

    _pickupLatLng = null; // Reset coordinate if user edits text to ensure they select a fresh suggestion.

    // Start a new 400ms countdown.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      _pickupSuggestions = suggestions;
      _showPickupSuggestions = suggestions.isNotEmpty;
      notifyListeners();
    });
  }

  /// Triggered when the text in the drop-off field changes.
  /// Implements debouncing to limit API calls during typing.
  void onDropChanged(String value) {
    // Cancel the pending timer from the previous keystroke.
    _debounce?.cancel();

    _dropLatLng = null; // Reset coordinate if user edits text.

    // Only execute the API call if the user stops typing for at least 400 milliseconds.
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      _dropSuggestions = suggestions;
      _showDropSuggestions = suggestions.isNotEmpty;
      notifyListeners();
    });
  }

  /// Finalizes the pickup location choice from the suggestion list.
  /// Fetches exact LatLng coordinates and updates the map marker.
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
      // Update markers set by replacing the old 'pickup' marker if it exists.
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
      // Move camera to the selected location.
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  /// Finalizes the drop-off location choice from the suggestion list.
  /// Fetches exact LatLng coordinates and updates the map marker.
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
      // Update markers set by replacing the old 'drop' marker if it exists.
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
      // Move camera to the selected location.
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  /// Forces the pickup suggestion list to show if suggestions already exist.
  void showPickupSuggestionList() {
    if (_pickupSuggestions.isNotEmpty) {
      _showPickupSuggestions = true;
      notifyListeners();
    }
  }

  /// Forces the drop-off suggestion list to show if suggestions already exist.
  void showDropSuggestionList() {
    if (_dropSuggestions.isNotEmpty) {
      _showDropSuggestions = true;
      notifyListeners();
    }
  }

  /// Calls Google Places Autocomplete API to get suggestions for the provided [input].
  Future<List<dynamic>> _fetchSuggestions(String input) async {
    if (input.isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}&key=$_apiKey&components=country:pk',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') return data['predictions'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('[Places] Autocomplete error: $e');
    }
    return [];
  }

  /// Calls Google Place Details API to fetch coordinates for a specific [placeId].
  Future<LatLng?> _fetchLatLng(String placeId) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          return LatLng(loc['lat'] as double, loc['lng'] as double);
        }
      }
    } catch (e) {
      debugPrint('[Places] Details error: $e');
    }
    return null;
  }

  @override
  void dispose() {
    // Cleanup controllers and timers to avoid memory leaks.
    pickupController.dispose();
    dropController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
