import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _apiKey = 'AIzaSyBiA_0nQ8UDLzi6uJ444825ZOoCi_-SHBc';

class RideResultScreen extends StatefulWidget {
  final LatLng pickupLatLng;
  final LatLng dropLatLng;
  final String pickupText;
  final String dropText;

  const RideResultScreen({
    super.key,
    required this.pickupLatLng,
    required this.dropLatLng,
    required this.pickupText,
    required this.dropText,
  });

  @override
  State<RideResultScreen> createState() => _RideResultScreenState();
}

class _RideResultScreenState extends State<RideResultScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  bool _loadingRoute = true;

  late final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('pickup'),
      position: widget.pickupLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: 'Pickup', snippet: widget.pickupText),
    ),
    Marker(
      markerId: const MarkerId('drop'),
      position: widget.dropLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Drop', snippet: widget.dropText),
    ),
  };

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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

  Future<void> _fetchRoute() async {
    final origin =
        '${widget.pickupLatLng.latitude},${widget.pickupLatLng.longitude}';
    final destination =
        '${widget.dropLatLng.latitude},${widget.dropLatLng.longitude}';
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
          final encoded =
              data['routes'][0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          if (mounted) {
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  color: const Color(0xFF5C2D91),
                  width: 5,
                ),
              };
              _loadingRoute = false;
            });
            _fitBounds();
          }
          return;
        }
        debugPrint('[Route] Directions API status: ${data['status']}');
      }
    } catch (e) {
      debugPrint('[Route] Error: $e');
    }
    // Fallback: straight line between the two points
    if (mounted) {
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [widget.pickupLatLng, widget.dropLatLng],
            color: const Color(0xFF5C2D91),
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
        _loadingRoute = false;
      });
      _fitBounds();
    }
  }

  void _fitBounds() {
    if (_mapController == null) return;
    final sw = LatLng(
      widget.pickupLatLng.latitude < widget.dropLatLng.latitude
          ? widget.pickupLatLng.latitude
          : widget.dropLatLng.latitude,
      widget.pickupLatLng.longitude < widget.dropLatLng.longitude
          ? widget.pickupLatLng.longitude
          : widget.dropLatLng.longitude,
    );
    final ne = LatLng(
      widget.pickupLatLng.latitude > widget.dropLatLng.latitude
          ? widget.pickupLatLng.latitude
          : widget.dropLatLng.latitude,
      widget.pickupLatLng.longitude > widget.dropLatLng.longitude
          ? widget.pickupLatLng.longitude
          : widget.dropLatLng.longitude,
    );
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_loadingRoute) _fitBounds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: widget.pickupLatLng,
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
              ),
            ),
          ),

          // Loading indicator over map while fetching route
          if (_loadingRoute)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C2D91)),
            ),

          // Bottom sheet
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const Text(
                      'Driver Found!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Driver card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C2D91).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF5C2D91).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5C2D91),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_bike,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bike',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Economy · 2-wheeler',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Rs. 180',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5C2D91),
                                ),
                              ),
                              Text(
                                'ETA 4 min',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route summary
                    Row(
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.circle, color: Colors.green, size: 12),
                            Container(
                                width: 2, height: 28, color: Colors.grey[300]),
                            const Icon(Icons.location_on,
                                color: Colors.red, size: 16),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.pickupText,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.dropText,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ride confirmed! Driver is on the way.'),
                              backgroundColor: Color(0xFF5C2D91),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C2D91),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm Ride',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
