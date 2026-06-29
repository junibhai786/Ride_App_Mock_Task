/// [Bid] represents a single driver bid on a ride request.
class Bid {
  final int id;
  final int rideId;
  final int driverId;
  final double amount;
  final String status;

  const Bid({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.amount,
    required this.status,
  });

  factory Bid.fromJson(Map<String, dynamic> json) => Bid(
        id: (json['id'] as num).toInt(),
        rideId: (json['ride_id'] as num).toInt(),
        driverId: (json['driver_id'] as num).toInt(),
        amount: double.parse(json['amount'].toString()),
        status: json['status'] as String,
      );
}
