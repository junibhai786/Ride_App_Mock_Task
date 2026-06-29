import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// [TrackingScreen] shows the driver moving toward the passenger in real-time
/// via Socket.io. The passenger socket listens for `location-updated` events
/// emitted by the driver's [DriverDashboardScreen] on the other phone.
/// Falls back to local simulation if no real driver update arrives within 5s.
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
  static const _serverUrl =
      'http://10.176.23.172:3000'; //'https://web-production-32998.up.railway.app';

  io.Socket? _passengerSocket;
  GoogleMapController? _mapController;
  Timer? _simulationTimer;
  Timer? _fallbackTimer;

  // Driver starts ~2 km northeast of the pickup point.
  late LatLng _driverPosition = LatLng(
    widget.pickupLatLng.latitude + 0.018,
    widget.pickupLatLng.longitude + 0.018,
  );

  Set<Marker> _markers = {};
  bool _isConnected = false;
  bool _receivedRealUpdate = false;

  @override
  void initState() {
    super.initState();
    _buildMarkers();
    _connectSockets();
  }

  void _buildMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(title: widget.driverName, snippet: 'On the way'),
      ),
    };
  }

  // ── Socket.io ──────────────────────────────────────────────────────────────

  void _connectSockets() {
    // --- Passenger socket: listens for location updates ---
    _passengerSocket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _passengerSocket!.onConnect((_) {
      debugPrint('[Socket] Passenger connected');
      _passengerSocket!.emit('join', {'role': 'passenger', 'id': 1});
      _passengerSocket!.emit('start-tracking', {
        'driverId': widget.driverId,
        'pickupLat': widget.pickupLatLng.latitude,
        'pickupLng': widget.pickupLatLng.longitude,
      });
      if (mounted) setState(() => _isConnected = true);
    });

    _passengerSocket!.on('location-updated', (data) {
      if (!mounted) return;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      _receivedRealUpdate = true;
      _fallbackTimer?.cancel(); // real driver connected — cancel fallback
      _simulationTimer?.cancel();
      _updateDriverMarker(LatLng(lat, lng));
    });

    _passengerSocket!.onDisconnect((_) {
      if (mounted) setState(() => _isConnected = false);
    });

    _passengerSocket!.connect();

    // If no real driver update in 5 seconds, fall back to local simulation.
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _receivedRealUpdate) return;
      debugPrint('[Socket] No real driver — starting local simulation');
      _startLocalSimulation();
    });
  }

  /// Used when the socket cannot connect — updates the marker locally.
  void _startLocalSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final newLat = _driverPosition.latitude +
          (widget.pickupLatLng.latitude - _driverPosition.latitude) * 0.15;
      final newLng = _driverPosition.longitude +
          (widget.pickupLatLng.longitude - _driverPosition.longitude) * 0.15;
      _driverPosition = LatLng(newLat, newLng);
      _updateDriverMarker(_driverPosition);
    });
  }

  void _updateDriverMarker(LatLng position) {
    if (!mounted) return;
    setState(() {
      _driverPosition = position;
      _markers = {
        ..._markers.where((m) => m.markerId.value != 'driver'),
        Marker(
          markerId: const MarkerId('driver'),
          position: position,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow:
              InfoWindow(title: widget.driverName, snippet: 'On the way'),
        ),
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _fallbackTimer?.cancel();
    _passengerSocket?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map.
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(_driverPosition, 14),
              );
            },
            initialCameraPosition: CameraPosition(
              target: _driverPosition,
              zoom: 14,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Top connection status badge.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Back button.
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            color: _isConnected ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _isConnected ? 'Live tracking' : 'Connecting...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isConnected
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Driver avatar.
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF5C2D91),
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

                      // Driver name + vehicle.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
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

                      // ETA.
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
                              color: Color(0xFF5C2D91),
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
