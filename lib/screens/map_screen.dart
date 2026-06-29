import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';

/// [MapScreen] is a standalone screen that displays a Google Map
/// centered on Lahore with a marker at Liberty Chowk.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// Single marker placed at the Lahore center coordinate.
  late final Set<Marker> _markers = {
    Marker(
      markerId: const MarkerId('lahore'),
      position: AppConstants.lahore,
      infoWindow: const InfoWindow(
        title: 'Lahore, Pakistan',
        snippet: 'Liberty Chowk',
      ),
    ),
  };

  GoogleMapController? _controller;

  /// Stores the map controller and immediately opens the marker info window.
  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    // Auto-open the info window so users see the location label right away.
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: AppConstants.lahore,
          zoom: 13,
        ),
        markers: _markers,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
