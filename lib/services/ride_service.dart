import 'dart:convert';

import 'package:ride_app_mock/core/errors/app_exception.dart';
import 'package:ride_app_mock/models/ride_details.dart';

class RideService {
  Future<RideDetails> fetchRideFare(String pickup, String drop) async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      const responseBody = '''
      {
        "vehicleType": "Bike",
        "fare": "Rs. 180",
        "eta": "4 min"
      }
      ''';
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      return RideDetails.fromJson(data);
    } catch (_) {
      throw const ParseException('Failed to load ride fare details.');
    }
  }
}
