import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/providers/driver_provider.dart';

/// [DriverDashboardScreen] is a pure UI layer.
///
/// All business logic (GPS, socket, broadcasting) lives in [DriverProvider].
/// This screen reads state from the provider and delegates every user action
/// to it. The only thing kept here is the [GoogleMapController] because
/// its lifecycle is tied to the [GoogleMap] widget.
class DriverDashboardScreen extends StatefulWidget {
  final int driverId;
  final String driverName;

  const DriverDashboardScreen({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  GoogleMapController? _mapController;

  /// Tracks the last known position so we can detect changes and animate.
  LatLng? _lastPosition;

  /// Tracks the last pickup so we only fit bounds when a new one arrives.
  LatLng? _lastPickup;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriverProvider>();
    // Bootstrap GPS + socket in the provider; no await — it notifies on changes.
    provider.init(widget.driverId, widget.driverName);
    // Listen so we can drive camera animations from outside the build method.
    provider.addListener(_onProviderUpdate);
  }

  /// Animates the camera whenever the provider emits a new position or pickup.
  void _onProviderUpdate() {
    final provider = context.read<DriverProvider>();

    // Animate to the new driver position if it changed.
    if (provider.currentPosition != _lastPosition) {
      _lastPosition = provider.currentPosition;
      if (provider.isOnline) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(provider.currentPosition),
        );
      }
    }

    // Fit driver + passenger in view when a ride is first assigned.
    if (provider.passengerPickup != null &&
        provider.passengerPickup != _lastPickup) {
      _lastPickup = provider.passengerPickup;
      _fitDriverAndPassenger(provider.currentPosition, provider.passengerPickup!);
    }
  }

  /// Animates the camera to show both the driver and the passenger pickup pins.
  void _fitDriverAndPassenger(LatLng driver, LatLng pickup) {
    final lat = pickup.latitude;
    final lng = pickup.longitude;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            lat < driver.latitude ? lat : driver.latitude,
            lng < driver.longitude ? lng : driver.longitude,
          ),
          northeast: LatLng(
            lat > driver.latitude ? lat : driver.latitude,
            lng > driver.longitude ? lng : driver.longitude,
          ),
        ),
        80,
      ),
    );
  }

  @override
  void dispose() {
    context.read<DriverProvider>()
      ..removeListener(_onProviderUpdate)
      ..cleanup();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map showing the driver's current GPS position.
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(
                CameraUpdate.newLatLngZoom(provider.currentPosition, 15),
              );
            },
            initialCameraPosition: CameraPosition(
              target: AppConstants.lahore,
              zoom: 15,
            ),
            myLocationEnabled: provider.locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            markers: {
              // Blue driver marker.
              Marker(
                markerId: const MarkerId('driver'),
                position: provider.currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow: InfoWindow(
                  title: widget.driverName,
                  snippet: provider.isOnline ? 'Online — broadcasting' : 'Offline',
                ),
              ),
              // Green passenger pickup marker — only shown when a ride is assigned.
              if (provider.passengerPickup != null)
                Marker(
                  markerId: const MarkerId('passenger'),
                  position: provider.passengerPickup!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  infoWindow: const InfoWindow(
                    title: 'Passenger',
                    snippet: 'Pickup location',
                  ),
                ),
            },
          ),

          // Top bar: back button + socket connection status badge.
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

                  // Connection status pill.
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
                          provider.isConnected
                              ? 'Server connected'
                              : 'Connecting...',
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

          // Bottom dashboard card: driver info + Go Online/Offline button.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle.
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Driver info row: avatar + name + update counter.
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.driverBlue,
                        child: Text(
                          widget.driverName.substring(0, 1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkNavy,
                              ),
                            ),
                            Text(
                              'Driver ID: ${widget.driverId}  ·  Honda CD-70',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      // Emitted update counter — only visible while broadcasting.
                      if (provider.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${provider.updateCount} updates',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Passenger pickup banner — appears when a ride is assigned.
                  if (provider.passengerPickup != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded,
                              color: Colors.green[700], size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ride assigned — Passenger waiting',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green[800],
                                  ),
                                ),
                                Text(
                                  '${provider.passengerPickup!.latitude.toStringAsFixed(5)}, '
                                  '${provider.passengerPickup!.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Current coordinates display — helpful for debugging GPS.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          '${provider.currentPosition.latitude.toStringAsFixed(6)}, '
                          '${provider.currentPosition.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.darkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Go Online / Go Offline toggle button.
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      // Delegates the toggle entirely to the provider.
                      onPressed: provider.toggleOnline,
                      style: ElevatedButton.styleFrom(
                        // Red when online (to stop), blue when offline (to start).
                        backgroundColor: provider.isOnline
                            ? Colors.red[400]
                            : AppColors.driverBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            provider.isOnline
                                ? Icons.wifi_off_rounded
                                : Icons.wifi_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              provider.isOnline
                                  ? 'Go Offline  (broadcasting every 2s)'
                                  : 'Go Online  —  Start Broadcasting',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Warning shown when GPS permission was denied.
                  if (!provider.locationPermissionGranted)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Location permission denied — grant it in Settings for real GPS',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11, color: Colors.orange[700]),
                      ),
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
