import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// [DriverDashboardScreen] — the driver's view.
/// Broadcasts real GPS location every 2 seconds via Socket.io when online.
/// Passenger's TrackingScreen receives these updates live.
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
  static const _serverUrl = 'http://10.176.23.172:3000';

  io.Socket? _socket;
  GoogleMapController? _mapController;
  Timer? _locationTimer;

  LatLng _currentPosition = const LatLng(31.5204, 74.3587); // Lahore default
  LatLng? _passengerPickup; // set when passenger starts tracking
  bool _isOnline = false;
  bool _isConnected = false;
  bool _locationPermissionGranted = false;
  int _updateCount = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _connectSocket();
  }

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    setState(() => _locationPermissionGranted = true);

    // Get initial position immediately
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition),
        );
      }
    } catch (_) {}
  }

  void _connectSocket() {
    _socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Driver] Socket connected');
      _socket!.emit('join', {
        'role': 'driver',
        'id': widget.driverId,
      });
      if (mounted) setState(() => _isConnected = true);
    });

    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _isConnected = false);
    });

    // Passenger has accepted the ride — show their pickup pin on the map.
    _socket!.on('passenger-pickup', (data) {
      if (!mounted) return;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final pickup = LatLng(lat, lng);
      setState(() => _passengerPickup = pickup);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              lat < _currentPosition.latitude ? lat : _currentPosition.latitude,
              lng < _currentPosition.longitude ? lng : _currentPosition.longitude,
            ),
            northeast: LatLng(
              lat > _currentPosition.latitude ? lat : _currentPosition.latitude,
              lng > _currentPosition.longitude ? lng : _currentPosition.longitude,
            ),
          ),
          80,
        ),
      );
      debugPrint('[Driver] Passenger pickup received: $lat, $lng');
    });

    _socket!.connect();
  }

  void _toggleOnline() {
    setState(() => _isOnline = !_isOnline);

    if (_isOnline) {
      _startBroadcasting();
    } else {
      _stopBroadcasting();
    }
  }

  /// Emits real GPS position to the server every 2 seconds.
  /// Passenger's socket receives `location-updated` with the same driverId.
  void _startBroadcasting() {
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted || !_isOnline) return;

      LatLng position;

      if (_locationPermissionGranted) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 1),
            ),
          );
          position = LatLng(pos.latitude, pos.longitude);
        } catch (_) {
          position = _currentPosition;
        }
      } else {
        position = _currentPosition;
      }

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _updateCount++;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(position));

      // Emit to server — passenger's socket will receive this via `location-updated`
      _socket?.emit('update-location', {
        'driverId': widget.driverId,
        'lat': position.latitude,
        'lng': position.longitude,
      });

      debugPrint('[Driver] Emitted location: ${position.latitude}, ${position.longitude}');
    });
  }

  void _stopBroadcasting() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  @override
  void dispose() {
    _stopBroadcasting();
    _socket?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map showing driver's current position
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(
                CameraUpdate.newLatLngZoom(_currentPosition, 15),
              );
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId('driver'),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow: InfoWindow(
                  title: widget.driverName,
                  snippet: _isOnline ? 'Online — broadcasting' : 'Offline',
                ),
              ),
              if (_passengerPickup != null)
                Marker(
                  markerId: const MarkerId('passenger'),
                  position: _passengerPickup!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  infoWindow: const InfoWindow(
                    title: 'Passenger',
                    snippet: 'Pickup location',
                  ),
                ),
            },
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Back button
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
                  // Connection status badge
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
                            color: _isConnected ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _isConnected ? 'Server connected' : 'Connecting...',
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

          // Bottom dashboard card
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
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Driver info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF1565C0),
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
                                color: Color(0xFF1A1A2E),
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
                      // Update counter badge
                      if (_isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_updateCount updates',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Passenger pickup banner — shown when a ride is assigned.
                  if (_passengerPickup != null) ...[
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
                                  '${_passengerPickup!.latitude.toStringAsFixed(5)}, '
                                  '${_passengerPickup!.longitude.toStringAsFixed(5)}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.green[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Coordinates display
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
                            size: 16, color: Color(0xFF5C2D91)),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentPosition.latitude.toStringAsFixed(6)}, '
                          '${_currentPosition.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Go Online / Go Offline button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _connectSocket == null ? null : _toggleOnline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline
                            ? Colors.red[400]
                            : const Color(0xFF1565C0),
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
                            _isOnline
                                ? Icons.wifi_off_rounded
                                : Icons.wifi_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _isOnline
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

                  if (!_locationPermissionGranted)
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
