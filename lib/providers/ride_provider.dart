import 'package:flutter/material.dart';
import 'package:ride_app_mock/models/ride_details.dart';
import 'package:ride_app_mock/services/ride_service.dart';

class RideProvider with ChangeNotifier {
  final RideService _rideService = RideService();

  RideDetails? _rideDetails;
  bool _isLoading = false;
  String? _error;

  RideDetails? get rideDetails => _rideDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> findRide(String pickup, String drop) async {
    if (pickup.isEmpty || drop.isEmpty) {
      _error = "Please enter both pickup and drop locations";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _rideDetails = null;
    _error = null;
    notifyListeners();

    try {
      _rideDetails = await _rideService.fetchRideFare(pickup, drop);
    } catch (e) {
      _error = "Failed to find a ride. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _rideDetails = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
