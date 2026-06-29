import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/providers/tracking_provider.dart';

/// [TrackingScreen] is a pure UI layer.
///
/// All socket, simulation, and position logic lives in [TrackingProvider].
/// This screen reads state from the provider and holds the [GoogleMapController]
/// (its lifecycle is tied to the [GoogleMap] widget).
class TrackingScreen extends StatefulWidget {
  final int rideId;
  final int driverId;
  final String driverName;
  final LatLng pickupLatLng;

  const TrackingScreen({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.pickupLatLng,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TrackingProvider>();
    // Bootstrap socket + simulation in the provider.
    provider.init(widget.driverId, widget.driverName, widget.pickupLatLng);
    // Animate the camera whenever the driver position changes.
    provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    final pos = context.read<TrackingProvider>().driverPosition;
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  void dispose() {
    context.read<TrackingProvider>()
      ..removeListener(_onProviderUpdate)
      ..cleanup();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingProvider>();
    final driverPos = provider.driverPosition;

    // Two static markers: green passenger pickup + violet driver position.
    final markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow:
            InfoWindow(title: widget.driverName, snippet: 'On the way'),
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map that tracks the driver's movement.
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(CameraUpdate.newLatLngZoom(driverPos, 14));
            },
            initialCameraPosition: CameraPosition(
              target: driverPos,
              zoom: 14,
            ),
            markers: markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Top bar: back button + live connection status badge.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
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
                  const SizedBox(width: 10),

                  // Connection status pill — green when socket is live.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: provider.isConnected
                                ? Colors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          provider.isConnected ? 'Live tracking' : 'Connecting...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: provider.isConnected
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom driver info card.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle.
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Text(
                    'Driver is on the way',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Driver avatar — first initial on brand-purple circle.
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          widget.driverName.substring(0, 1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Driver name, rating, and vehicle.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '4.8 · Honda CD-70',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ETA column on the right.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Arriving in',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                          const Text(
                            '~4 min',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
