import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/models/bid.dart';

/// A single driver bid card shown inside [BidList].
/// Displays the driver's avatar, name, rating, vehicle, and bid amount.
/// Shows a loading spinner on the Accept button while the bid is being processed.
class BidCard extends StatelessWidget {
  final Bid bid;
  final String driverName;

  /// True while this specific bid is being accepted (shows spinner).
  final bool isAccepting;

  /// True when another bid is being accepted — disables this card's button.
  final bool isDisabled;

  final VoidCallback onAccept;

  const BidCard({
    super.key,
    required this.bid,
    required this.driverName,
    required this.isAccepting,
    required this.isDisabled,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    // Hardcoded mock values — would come from the driver model in a real app.
    const rating = '4.8';
    const vehicle = 'Honda CD-70';

    // First letter of the driver's name used as a fallback avatar.
    final initial = driverName.substring(0, 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Driver avatar showing first initial on brand-purple background.
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Driver name, rating, and vehicle info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driverName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        '$rating · $vehicle',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bid fare and Accept button stacked vertically on the right.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bid amount in brand color.
                Text(
                  'Rs. ${bid.amount.toInt()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: 88,
                  height: 36,
                  child: ElevatedButton(
                    // Disable button when another bid is already being accepted.
                    onPressed: isDisabled ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: isAccepting
                        // Spinner while waiting for the server to confirm.
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Accept',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
