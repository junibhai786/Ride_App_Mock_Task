import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ride_app_mock/core/constants/app_constants.dart';

/// [TrackingProvider] owns all passenger-side tracking logic:
/// socket connection, real-time driver position updates, and the local
/// fallback simulation when no real driver is broadcasting.
///
/// The screen holds the [GoogleMapController]; it adds a listener to this
/// provider and calls [animateCamera] whenever [driverPosition] changes.
class TrackingProvider with ChangeNotifier {
  io.Socket? _passengerSocket;
  Timer? _simulationTimer;

  /// Fires once after 5 seconds — triggers local simulation if no real update arrives.
  Timer? _fallbackTimer;

  LatLng _driverPosition = AppConstants.lahore;
  LatLng _pickupLatLng = AppConstants.lahore;
  bool _isConnected = false;

  /// Becomes true as soon as the first real `location-updated` socket event arrives.
  bool _receivedRealUpdate = false;

  // ── Getters ─────────────────────────────────────────────────────────────────

  LatLng get driverPosition => _driverPosition;
  bool get isConnected => _isConnected;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Called from the screen's [initState] to bootstrap socket and simulation.
  void init(int driverId, String driverName, LatLng pickupLatLng) {
    _pickupLatLng = pickupLatLng;
    _receivedRealUpdate = false;

    // Place the driver ~2 km north-east of the pickup point for demo purposes.
    _driverPosition = LatLng(
      pickupLatLng.latitude + 0.018,
      pickupLatLng.longitude + 0.018,
    );

    _connectSocket(driverId, pickupLatLng);
  }

  /// Cancels all timers and disconnects the socket.
  /// The screen calls this in its [dispose].
  void cleanup() {
    _simulationTimer?.cancel();
    _fallbackTimer?.cancel();
    _passengerSocket?.dispose();
    _passengerSocket = null;
    notifyListeners();
  }

  // ── Socket.io ────────────────────────────────────────────────────────────────

  void _connectSocket(int driverId, LatLng pickupLatLng) {
    _passengerSocket = io.io(
      AppConstants.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    );

    _passengerSocket!.onConnect((_) {
      debugPrint('[Socket] Passenger connected');
      // Register as a passenger and subscribe to this driver's location stream.
      _passengerSocket!.emit('join', {'role': 'passenger', 'id': 1});
      _passengerSocket!.emit('start-tracking', {
        'driverId': driverId,
        'pickupLat': pickupLatLng.latitude,
        'pickupLng': pickupLatLng.longitude,
      });
      _isConnected = true;
      notifyListeners();
    });

    _passengerSocket!.onConnectError(
      (err) => debugPrint('[Socket] Connect error: $err'),
    );

    // Receives real GPS from the driver's [DriverProvider].
    _passengerSocket!.on('location-updated', (data) {
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      // Cancel simulation — real updates are now flowing.
      _receivedRealUpdate = true;
      _fallbackTimer?.cancel();
      _simulationTimer?.cancel();
      _driverPosition = LatLng(lat, lng);
      notifyListeners(); // Screen observes and animates the camera.
    });

    _passengerSocket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });

    _passengerSocket!.connect();

    // If no real driver update arrives within 5 seconds, start local simulation.
    _fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (_receivedRealUpdate) return;
      debugPrint('[Socket] No real driver update — starting local simulation');
      _startLocalSimulation();
    });
  }

  // ── Local simulation ─────────────────────────────────────────────────────────

  /// Interpolates the driver marker 15% closer to the pickup every 2 seconds.
  /// Used only when no real driver socket is reachable.
  void _startLocalSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final newLat = _driverPosition.latitude +
          (_pickupLatLng.latitude - _driverPosition.latitude) * 0.15;
      final newLng = _driverPosition.longitude +
          (_pickupLatLng.longitude - _driverPosition.longitude) * 0.15;
      _driverPosition = LatLng(newLat, newLng);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
