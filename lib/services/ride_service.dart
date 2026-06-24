import 'dart:convert';
import 'package:ride_app_mock/models/ride_details.dart';

class RideService {
  /// Simulates fetching ride details from a remote API
  Future<RideDetails> fetchRideFare(String pickup, String drop) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock JSON response
    final String responseBody = '''
    {
      "vehicleType": "Bike",
      "fare": "Rs. 180",
      "eta": "4 min"
    }
    ''';

    final Map<String, dynamic> data = jsonDecode(responseBody);
    return RideDetails.fromJson(data);
  }
}
