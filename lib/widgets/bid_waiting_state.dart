import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';

/// Shown on [BiddingScreen] while the app waits for driver bids to arrive.
/// An animated pulsing circle provides visual feedback that something is happening.
class BidWaitingState extends StatelessWidget {
  /// Animation controller that drives the pulse effect (repeat + reverse).
  final AnimationController pulseController;

  const BidWaitingState({super.key, required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing icon circle — opacity oscillates with the animation value.
          AnimatedBuilder(
            animation: pulseController,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary
                    .withValues(alpha: 0.15 + 0.15 * pulseController.value),
              ),
              child: const Icon(
                Icons.directions_bike,
                size: 38,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Finding drivers nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Drivers are placing their bids...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Spinner to reinforce that the app is actively working.
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}
