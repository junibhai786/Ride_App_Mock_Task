import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// [MapScreen] is a standalone screen (Task 3) that displays a Google Map
/// centered on Lahore with a specific marker at Liberty Chowk.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Hardcoded coordinates for the map center (Lahore).
  static const LatLng _lahore = LatLng(31.5204, 74.3587);

  // Set of markers to be displayed on the map.
  late final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('lahore'),
      position: _lahore,
      infoWindow: const InfoWindow(
        title: 'Lahore, Pakistan',
        snippet: 'Liberty Chowk',
      ),
    ),
  };

  GoogleMapController? _controller;

  /// Callback when the Google Map is successfully created.
  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    // Automatically open the info window to make the marker details visible immediately on launch.
    _controller!.showMarkerInfoWindow(const MarkerId('lahore'));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lahore on Map'),
        backgroundColor: const Color(0xFF5C2D91),
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: _lahore,
          zoom: 13,
        ),
        markers: _markers,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
