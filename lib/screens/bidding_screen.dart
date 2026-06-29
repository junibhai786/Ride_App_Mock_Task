import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/models/bid.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/screens/tracking_screen.dart';
import 'package:ride_app_mock/widgets/bid_error_state.dart';
import 'package:ride_app_mock/widgets/bid_list.dart';
import 'package:ride_app_mock/widgets/bid_waiting_state.dart';

/// [BiddingScreen] shows incoming driver bids in real-time and lets
/// the passenger accept one to confirm the ride.
class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the pulsing animation on the waiting state icon.
  late AnimationController _pulseController;

  /// Tracks which bid ID is currently being accepted so only that card shows a spinner.
  int? _acceptingBidId;

  @override
  void initState() {
    super.initState();
    // 900 ms repeating animation for the pulsing circle effect.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Called when the passenger taps "Accept" on a bid card.
  Future<void> _onAccept(Bid bid) async {
    setState(() => _acceptingBidId = bid.id);

    final biddingProvider = context.read<BiddingProvider>();
    final success = await biddingProvider.acceptBid(bid.id);

    if (!mounted) return;

    if (success) {
      final driverId = biddingProvider.acceptedDriverId ?? bid.driverId;
      final driverName = biddingProvider.driverName(driverId);
      final pickupLatLng = context.read<RideProvider>().pickupLatLng;

      if (pickupLatLng == null) return;

      // Replace this screen with the live tracking view.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(
            rideId: biddingProvider.rideId!,
            driverId: driverId,
            driverName: driverName,
            pickupLatLng: pickupLatLng,
          ),
        ),
      );
    } else {
      setState(() => _acceptingBidId = null);
      // Surface the error if the backend rejected the accept request.
      if (biddingProvider.exception != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(biddingProvider.exception!.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bidding = context.watch<BiddingProvider>();
    final isWaiting = bidding.status == BiddingStatus.waitingForBids;
    final isCreating = bidding.status == BiddingStatus.creatingRide;
    final isError = bidding.status == BiddingStatus.error;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Choose a Driver'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Purple header strip showing how many bids have arrived.
          Container(
            color: AppColors.primary,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              isCreating
                  ? 'Creating your ride request...'
                  : isWaiting && bidding.bids.isEmpty
                      ? 'Searching for nearby drivers...'
                      : '${bidding.bids.length} driver${bidding.bids.length == 1 ? '' : 's'} found',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),

          // Body swaps between error, waiting, and bid list states.
          Expanded(
            child: isError
                ? BidErrorState(
                    message: bidding.exception?.message ?? 'Something went wrong',
                    onRetry: () {
                      final rp = context.read<RideProvider>();
                      context.read<BiddingProvider>().createRide(
                            rp.pickupLatLng!,
                            rp.dropLatLng!,
                          );
                    },
                  )
                : isCreating || (isWaiting && bidding.bids.isEmpty)
                    ? BidWaitingState(pulseController: _pulseController)
                    : BidList(
                        bids: bidding.bids,
                        acceptingBidId: _acceptingBidId,
                        onAccept: _onAccept,
                      ),
          ),
        ],
      ),
    );
  }
}
