import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_app_mock/models/bid.dart';

enum BiddingStatus {
  idle,
  creatingRide,
  waitingForBids,
  bidsReceived,
  accepting,
  accepted,
  error
}

/// [BiddingProvider] manages the full ride bidding lifecycle:
/// create ride → fetch real drivers → place bids → accept one bid.
class BiddingProvider with ChangeNotifier {
  static const _baseUrl =
      'http://10.176.23.172:3000'; //'https://web-production-32998.up.railway.app';

  int? _rideId;
  List<Bid> _bids = [];
  BiddingStatus _status = BiddingStatus.idle;
  String? _error;
  int? _acceptedDriverId;

  // Real drivers fetched from /api/drivers/online
  List<Map<String, dynamic>> _onlineDrivers = [];

  int? get rideId => _rideId;
  List<Bid> get bids => List.unmodifiable(_bids);
  BiddingStatus get status => _status;
  String? get error => _error;
  int? get acceptedDriverId => _acceptedDriverId;

  String driverName(int id) {
    final d = _onlineDrivers.firstWhere(
      (d) => d['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return (d['name'] as String?) ?? 'Driver $id';
  }

  // ── Create Ride ─────────────────────────────────────────────────────────────

  Future<void> createRide(LatLng pickup, LatLng drop) async {
    _status = BiddingStatus.creatingRide;
    _bids = [];
    _rideId = null;
    _error = null;
    _acceptedDriverId = null;
    notifyListeners();

    final url = '$_baseUrl/api/rides/request';
    final body = jsonEncode({
      'passengerId': 1,
      'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
      'destination': {'lat': drop.latitude, 'lng': drop.longitude},
    });
    debugPrint('[Bidding] POST $url');
    debugPrint('[Bidding] body: $body');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[Bidding] status: ${response.statusCode}');
      debugPrint('[Bidding] body:   ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        _rideId = (data['ride']['id'] as num).toInt();
        _status = BiddingStatus.waitingForBids;
        notifyListeners();
        _simulateDriverBids();
      } else {
        _error = data['message'] as String? ?? 'Failed to create ride';
        _status = BiddingStatus.error;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Bidding] ERROR: $e');
      debugPrint('[Bidding] URL was: $url');
      _error = 'Network error. Check your connection and try again.';
      _status = BiddingStatus.error;
      notifyListeners();
    }
  }

  // ── Place Real Driver Bids ──────────────────────────────────────────────────

  void _simulateDriverBids() async {
    // 1. Fetch real online drivers from the database.
    List<Map<String, dynamic>> drivers = [];
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/api/drivers/online'))
          .timeout(const Duration(seconds: 8));
      debugPrint('[Bidding] Drivers status: ${resp.statusCode} body: ${resp.body}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        drivers = (data['drivers'] as List).map((d) => {
          'id': (d['id'] as num).toInt(),
          'name': d['name'] as String,
        }).toList();
        _onlineDrivers = List.from(drivers);
      }
    } catch (e) {
      debugPrint('[Bidding] Fetch drivers error: $e');
    }

    // Fallback: if API unreachable, use the seeded driver.
    if (drivers.isEmpty) {
      drivers = [{'id': 1, 'name': 'Ahmed Ali'}];
      _onlineDrivers = List.from(drivers);
    }

    // 2. Each driver places a bid with a staggered delay.
    final amounts = [180, 195, 220];
    for (int i = 0; i < drivers.length; i++) {
      await Future.delayed(Duration(milliseconds: 1000 + i * 1500));
      if (_rideId == null || _status == BiddingStatus.accepted) return;

      final driverId = drivers[i]['id'] as int;
      final amount = amounts[i % amounts.length];
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/api/rides/$_rideId/bid'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'driverId': driverId, 'amount': amount}),
            )
            .timeout(const Duration(seconds: 8));

        debugPrint('[Bidding] Place bid $driverId status: ${response.statusCode}');
        if (response.statusCode == 200) {
          await _fetchBids();
        }
      } catch (e) {
        debugPrint('[Bidding] Place bid error: $e');
      }
    }
  }

  Future<void> _fetchBids() async {
    if (_rideId == null) return;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/rides/$_rideId/bids'))
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        _bids = (data['bids'] as List)
            .map((b) => Bid.fromJson(b as Map<String, dynamic>))
            .toList();
        if (_bids.isNotEmpty && _status == BiddingStatus.waitingForBids) {
          _status = BiddingStatus.bidsReceived;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Bidding] Fetch bids error: $e');
    }
  }

  // ── Accept Bid ──────────────────────────────────────────────────────────────

  Future<bool> acceptBid(int bidId) async {
    if (_rideId == null) return false;

    _status = BiddingStatus.accepting;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rides/$_rideId/accept-bid'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'bidId': bidId}),
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('[Bidding] Accept bid status: ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        _acceptedDriverId = (data['driverId'] as num).toInt();
        _status = BiddingStatus.accepted;
        notifyListeners();
        return true;
      } else {
        _error = data['message'] as String? ?? 'Failed to accept bid';
        _status = BiddingStatus.bidsReceived;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[Bidding] Accept bid error: $e');
      _error = 'Network error. Please try again.';
      _status = BiddingStatus.bidsReceived;
      notifyListeners();
      return false;
    }
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  void reset() {
    _rideId = null;
    _bids = [];
    _status = BiddingStatus.idle;
    _error = null;
    _acceptedDriverId = null;
    _onlineDrivers = [];
    notifyListeners();
  }
}
