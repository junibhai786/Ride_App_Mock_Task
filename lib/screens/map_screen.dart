import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Standalone Task 3 screen: opens Google Maps centred on Lahore
/// with a marker placed at Liberty Chowk, Lahore.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _lahore = LatLng(31.5204, 74.3587);

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

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    // Open the info window automatically so the label is visible on launch
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
