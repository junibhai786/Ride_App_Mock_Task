import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'ride_result_screen.dart';

const _apiKey = 'AIzaSyBiA_0nQ8UDLzi6uJ444825ZOoCi_-SHBc';

class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({super.key});

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();

  static const LatLng _lahore = LatLng(31.5204, 74.3587);

  GoogleMapController? _mapController;

  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;

  List<dynamic> _pickupSuggestions = [];
  List<dynamic> _dropSuggestions = [];

  bool _showPickupSuggestions = false;
  bool _showDropSuggestions = false;

  Timer? _debounce;

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('lahore'),
      position: _lahore,
      infoWindow: InfoWindow(title: 'Lahore', snippet: 'Heart of Pakistan'),
    ),
  };

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _mapController?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<List<dynamic>> _fetchSuggestions(String input) async {
    if (input.isEmpty) return [];
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}&key=$_apiKey&components=country:pk',
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') return data['predictions'] as List<dynamic>;
    }
    return [];
  }

  Future<LatLng?> _fetchLatLng(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId&fields=geometry&key=$_apiKey',
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        return LatLng(loc['lat'], loc['lng']);
      }
    }
    return null;
  }

  void _onPickupChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      if (mounted) {
        setState(() {
          _pickupSuggestions = suggestions;
          _showPickupSuggestions = suggestions.isNotEmpty;
          _pickupLatLng = null;
        });
      }
    });
  }

  void _onDropChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final suggestions = await _fetchSuggestions(value);
      if (mounted) {
        setState(() {
          _dropSuggestions = suggestions;
          _showDropSuggestions = suggestions.isNotEmpty;
          _dropLatLng = null;
        });
      }
    });
  }

  Future<void> _selectPickup(dynamic prediction) async {
    final description = prediction['description'] as String;
    final placeId = prediction['place_id'] as String;
    _pickupController.text = description;
    setState(() {
      _showPickupSuggestions = false;
      _pickupSuggestions = [];
    });
    final latLng = await _fetchLatLng(placeId);
    if (latLng != null && mounted) {
      setState(() {
        _pickupLatLng = latLng;
        _markers.removeWhere((m) => m.markerId.value == 'pickup');
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup', snippet: description),
        ));
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  Future<void> _selectDrop(dynamic prediction) async {
    final description = prediction['description'] as String;
    final placeId = prediction['place_id'] as String;
    _dropController.text = description;
    setState(() {
      _showDropSuggestions = false;
      _dropSuggestions = [];
    });
    final latLng = await _fetchLatLng(placeId);
    if (latLng != null && mounted) {
      setState(() {
        _dropLatLng = latLng;
        _markers.removeWhere((m) => m.markerId.value == 'drop');
        _markers.add(Marker(
          markerId: const MarkerId('drop'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Drop', snippet: description),
        ));
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    }
  }

  void _findRide() {
    if (_pickupLatLng == null || _dropLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and drop locations from the suggestions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideResultScreen(
          pickupLatLng: _pickupLatLng!,
          dropLatLng: _dropLatLng!,
          pickupText: _pickupController.text,
          dropText: _dropController.text,
        ),
      ),
    );
  }

  Widget _buildSuggestionList(List<dynamic> suggestions, Function(dynamic) onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length > 5 ? 5 : suggestions.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final prediction = suggestions[index];
          final mainText = prediction['structured_formatting']?['main_text'] as String? ??
              prediction['description'] as String;
          final secondaryText =
              prediction['structured_formatting']?['secondary_text'] as String? ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on, color: Color(0xFF5C2D91), size: 20),
            title: Text(mainText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: secondaryText.isNotEmpty
                ? Text(secondaryText, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                : null,
            onTap: () => onTap(prediction),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Ride'),
        backgroundColor: const Color(0xFF5C2D91),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 280,
              child: GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                initialCameraPosition: const CameraPosition(
                  target: _lahore,
                  zoom: 13,
                ),
                markers: _markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Improved Location Selection Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Left side: Route visualizer
                          Column(
                            children: [
                              const Icon(Icons.radio_button_checked, color: Colors.green, size: 20),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const Icon(Icons.location_on, color: Colors.red, size: 20),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Right side: TextFields
                          Expanded(
                            child: Column(
                              children: [
                                // Pickup Field
                                TextField(
                                  controller: _pickupController,
                                  decoration: const InputDecoration(
                                    hintText: 'Pickup Location',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onChanged: _onPickupChanged,
                                  onTap: () {
                                    if (_pickupSuggestions.isNotEmpty) {
                                      setState(() => _showPickupSuggestions = true);
                                    }
                                  },
                                ),
                                Divider(height: 1, color: Colors.grey[200]),
                                // Drop Field
                                TextField(
                                  controller: _dropController,
                                  decoration: const InputDecoration(
                                    hintText: 'Drop Location',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onChanged: _onDropChanged,
                                  onTap: () {
                                    if (_dropSuggestions.isNotEmpty) {
                                      setState(() => _showDropSuggestions = true);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Suggestions (Overlay logic or below)
                  if (_showPickupSuggestions && _pickupSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(_pickupSuggestions, _selectPickup),
                    ),
                  if (_showDropSuggestions && _dropSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(_dropSuggestions, _selectDrop),
                    ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _findRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C2D91),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Find Ride', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
