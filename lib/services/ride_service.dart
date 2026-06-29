import 'dart:convert';
import 'package:ride_app_mock/models/ride_details.dart';

/// [RideService] handles data retrieval for ride-related information.
/// Currently simulates a network request with hardcoded mock data.
class RideService {
  /// Simulates fetching ride fare and vehicle details from a remote API.
  /// Returns a [RideDetails] object after a simulated network delay.
  Future<RideDetails> fetchRideFare(String pickup, String drop) async {
    // Simulate network latency (2 seconds).
    await Future.delayed(const Duration(seconds: 2));

    // Mock JSON response representing a ride result from a backend.
    final String responseBody = '''
    {
      "vehicleType": "Bike",
      "fare": "Rs. 180",
      "eta": "4 min"
    }
    ''';

    // Parse the JSON string and map it to the domain model.
    final Map<String, dynamic> data = jsonDecode(responseBody);
    return RideDetails.fromJson(data);
  }
}
