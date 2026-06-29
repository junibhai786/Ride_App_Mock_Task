import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ride_app_mock/core/constants/app_constants.dart';

/// [DriverProvider] owns all driver-side business logic:
/// GPS permission, real-time location broadcasting, and Socket.io connectivity.
///
/// The screen holds the [GoogleMapController] for camera animations;
/// it listens to this provider and animates when [currentPosition] or
/// [passengerPickup] changes.
class DriverProvider with ChangeNotifier {
  io.Socket? _socket;

  /// Fires every 2 seconds while the driver is online to emit GPS to the server.
  Timer? _locationTimer;

  LatLng _currentPosition = AppConstants.lahore;
  LatLng? _passengerPickup;
  bool _isOnline = false;
  bool _isConnected = false;
  bool _locationPermissionGranted = false;

  /// Counts how many location updates have been emitted this session.
  int _updateCount = 0;

  int _driverId = 0;

  // ── Getters ─────────────────────────────────────────────────────────────────

  LatLng get currentPosition => _currentPosition;
  LatLng? get passengerPickup => _passengerPickup;
  bool get isOnline => _isOnline;
  bool get isConnected => _isConnected;
  bool get locationPermissionGranted => _locationPermissionGranted;
  int get updateCount => _updateCount;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Called from the screen's [initState] to bootstrap GPS and socket.
  Future<void> init(int driverId, String driverName) async {
    _driverId = driverId;
    // Reset positional state before reconnecting.
    _currentPosition = AppConstants.lahore;
    _passengerPickup = null;
    _updateCount = 0;
    await _initLocation();
    _connectSocket(driverId);
  }

  /// Cancels the timer, disconnects the socket, and resets mutable state.
  /// The screen calls this in its [dispose].
  void cleanup() {
    _stopBroadcasting();
    _socket?.dispose();
    _socket = null;
    _isOnline = false;
    _isConnected = false;
    _updateCount = 0;
    _passengerPickup = null;
    notifyListeners();
  }

  // ── GPS / Location ───────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Permanently denied — continue with the Lahore default; no GPS available.
    if (permission == LocationPermission.deniedForever) return;

    _locationPermissionGranted = true;
    notifyListeners();

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (_) {
      // GPS unavailable — keep the Lahore default.
    }
  }

  // ── Socket.io ────────────────────────────────────────────────────────────────

  void _connectSocket(int driverId) {
    _socket = io.io(
      AppConstants.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Driver] Socket connected');
      // Identify this device to the server as a driver.
      _socket!.emit('join', {'role': 'driver', 'id': driverId});
      _isConnected = true;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    // Server sends this when a passenger accepts this driver's bid.
    _socket!.on('passenger-pickup', (data) {
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      _passengerPickup = LatLng(lat, lng);
      notifyListeners();
    });

    _socket!.connect();
  }

  // ── Online / Offline toggle ───────────────────────────────────────────────────

  /// Toggles the driver's online status and starts/stops GPS broadcasting.
  void toggleOnline() {
    _isOnline = !_isOnline;
    notifyListeners();
    if (_isOnline) {
      _startBroadcasting();
    } else {
      _stopBroadcasting();
    }
  }

  /// Emits real GPS coordinates to the server every 2 seconds.
  void _startBroadcasting() {
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      LatLng position;

      if (_locationPermissionGranted) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              // 1-second timeout keeps the 2-second interval healthy.
              timeLimit: Duration(seconds: 1),
            ),
          );
          position = LatLng(pos.latitude, pos.longitude);
        } catch (_) {
          // GPS timed out mid-broadcast — reuse the last known position.
          position = _currentPosition;
        }
      } else {
        position = _currentPosition;
      }

      _currentPosition = position;
      _updateCount++;
      notifyListeners(); // Screen observes and animates the camera.

      // Broadcast to the server — passenger socket receives `location-updated`.
      _socket?.emit('update-location', {
        'driverId': _driverId,
        'lat': position.latitude,
        'lng': position.longitude,
      });

      debugPrint('[Driver] Emitted: ${position.latitude}, ${position.longitude}');
    });
  }

  void _stopBroadcasting() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
