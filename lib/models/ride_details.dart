/// [RideDetails] is a data model representing the calculated ride information
/// including vehicle type, price, and estimated time of arrival.
class RideDetails {
  final String vehicleType;
  final String fare;
  final String eta;

  RideDetails({
    required this.vehicleType,
    required this.fare,
    required this.eta,
  });

  /// Factory constructor to create a [RideDetails] instance from a JSON map.
  factory RideDetails.fromJson(Map<String, dynamic> json) {
    return RideDetails(
      vehicleType: json['vehicleType'] ?? 'Bike',
      fare: json['fare'] ?? 'Rs. 0',
      eta: json['eta'] ?? '0 min',
    );
  }
}
