import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/core/errors/app_exception.dart';
import 'package:ride_app_mock/core/network/api_client.dart';
import 'package:ride_app_mock/models/bid.dart';

enum BiddingStatus {
  idle,
  creatingRide,
  waitingForBids,
  bidsReceived,
  accepting,
  accepted,
  error,
}

class BiddingProvider with ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────

  int? _rideId;
  List<Bid> _bids = [];
  BiddingStatus _status = BiddingStatus.idle;
  AppException? _exception;
  int? _acceptedDriverId;
  List<Map<String, dynamic>> _onlineDrivers = [];

  // ── Getters ────────────────────────────────────────────────────────────────

  int? get rideId => _rideId;
  List<Bid> get bids => List.unmodifiable(_bids);
  BiddingStatus get status => _status;
  AppException? get exception => _exception;
  int? get acceptedDriverId => _acceptedDriverId;

  String driverName(int id) {
    final driver = _onlineDrivers.firstWhere(
      (d) => d['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return (driver['name'] as String?) ?? 'Driver $id';
  }

  // ── Create Ride ─────────────────────────────────────────────────────────────

  Future<void> createRide(LatLng pickup, LatLng drop) async {
    _status = BiddingStatus.creatingRide;
    _bids = [];
    _rideId = null;
    _exception = null;
    _acceptedDriverId = null;
    notifyListeners();

    try {
      final data = await ApiClient.post(
        '${AppConstants.serverUrl}/api/rides/request',
        body: {
          'passengerId': 1,
          'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
          'destination': {'lat': drop.latitude, 'lng': drop.longitude},
        },
      );

      if (data['success'] == true) {
        _rideId = (data['ride']['id'] as num).toInt();
        _status = BiddingStatus.waitingForBids;
        notifyListeners();
        _simulateDriverBids();
      } else {
        throw ServerException(
          data['message'] as String? ?? 'Failed to create ride.',
          statusCode: 200,
        );
      }
    } on AppException catch (e) {
      debugPrint('[Bidding] createRide error: $e');
      _exception = e;
      _status = BiddingStatus.error;
      notifyListeners();
    }
  }

  // ── Simulate Driver Bids ────────────────────────────────────────────────────

  void _simulateDriverBids() async {
    List<Map<String, dynamic>> drivers = [];

    try {
      final data =
          await ApiClient.get('${AppConstants.serverUrl}/api/drivers/online');

      if (data['success'] == true) {
        drivers = (data['drivers'] as List)
            .map((d) => {
                  'id': (d['id'] as num).toInt(),
                  'name': d['name'] as String,
                })
            .toList();
        _onlineDrivers = List.from(drivers);
      }
    } on AppException catch (e) {
      debugPrint('[Bidding] fetchDrivers error: $e');
    }

    if (drivers.isEmpty) {
      drivers = [
        {'id': 1, 'name': 'Ahmed Ali'}
      ];
      _onlineDrivers = List.from(drivers);
    }

    final amounts = [180, 195, 220];
    for (int i = 0; i < drivers.length; i++) {
      await Future.delayed(Duration(milliseconds: 1000 + i * 1500));

      if (_rideId == null || _status == BiddingStatus.accepted) return;

      final driverId = drivers[i]['id'] as int;
      final amount = amounts[i % amounts.length];

      try {
        await ApiClient.post(
          '${AppConstants.serverUrl}/api/rides/$_rideId/bid',
          body: {'driverId': driverId, 'amount': amount},
        );
        await _fetchBids();
      } on AppException catch (e) {
        debugPrint('[Bidding] placeBid error for driver $driverId: $e');
      }
    }
  }

  Future<void> _fetchBids() async {
    if (_rideId == null) return;

    try {
      final data =
          await ApiClient.get('${AppConstants.serverUrl}/api/rides/$_rideId/bids');

      if (data['success'] == true) {
        _bids = (data['bids'] as List)
            .map((b) => Bid.fromJson(b as Map<String, dynamic>))
            .toList();

        if (_bids.isNotEmpty && _status == BiddingStatus.waitingForBids) {
          _status = BiddingStatus.bidsReceived;
        }
        notifyListeners();
      }
    } on AppException catch (e) {
      debugPrint('[Bidding] fetchBids error: $e');
    }
  }

  // ── Accept Bid ──────────────────────────────────────────────────────────────

  Future<bool> acceptBid(int bidId) async {
    if (_rideId == null) return false;

    _status = BiddingStatus.accepting;
    _exception = null;
    notifyListeners();

    try {
      final data = await ApiClient.post(
        '${AppConstants.serverUrl}/api/rides/$_rideId/accept-bid',
        body: {'bidId': bidId},
      );

      if (data['success'] == true) {
        _acceptedDriverId = (data['driverId'] as num).toInt();
        _status = BiddingStatus.accepted;
        notifyListeners();
        return true;
      }

      throw ServerException(
        data['message'] as String? ?? 'Failed to accept bid.',
        statusCode: 200,
      );
    } on AppException catch (e) {
      debugPrint('[Bidding] acceptBid error: $e');
      _exception = e;
      _status = BiddingStatus.bidsReceived;
      notifyListeners();
      return false;
    }
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  void reset() {
    _rideId = null;
    _bids = [];
    _status = BiddingStatus.idle;
    _exception = null;
    _acceptedDriverId = null;
    _onlineDrivers = [];
    notifyListeners();
  }
}
