import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';

/// Shown on [BiddingScreen] when ride creation or bid fetching fails.
/// Displays the error message and a retry button.
class BidErrorState extends StatelessWidget {
  /// Human-readable error message from the provider.
  final String message;

  /// Called when the user taps "Try Again".
  final VoidCallback onRetry;

  const BidErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large error icon for immediate visual recognition.
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 24),

            // Retry button — triggers the ride creation flow again.
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
