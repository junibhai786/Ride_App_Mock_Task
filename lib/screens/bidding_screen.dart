import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/models/bid.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/screens/tracking_screen.dart';


/// [BiddingScreen] displays incoming driver bids in real-time and lets
/// the passenger accept one to confirm the ride.
class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int? _acceptingBidId;

  @override
  void initState() {
    super.initState();
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
      if (biddingProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(biddingProvider.error!),
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
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Choose a Driver'),
        backgroundColor: const Color(0xFF5C2D91),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Purple header strip with ride status.
          Container(
            color: const Color(0xFF5C2D91),
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

          Expanded(
            child: isError
                ? _ErrorState(
                    message: bidding.error ?? 'Something went wrong',
                    onRetry: () {
                      final rp = context.read<RideProvider>();
                      context.read<BiddingProvider>().createRide(
                            rp.pickupLatLng!,
                            rp.dropLatLng!,
                          );
                    },
                  )
                : isCreating || (isWaiting && bidding.bids.isEmpty)
                    ? _WaitingState(pulseController: _pulseController)
                    : _BidList(
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

// ── Waiting State ────────────────────────────────────────────────────────────

class _WaitingState extends StatelessWidget {
  final AnimationController pulseController;
  const _WaitingState({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5C2D91)
                    .withValues(alpha: 0.15 + 0.15 * pulseController.value),
              ),
              child: const Icon(Icons.directions_bike,
                  size: 38, color: Color(0xFF5C2D91)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Finding drivers nearby',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drivers are placing their bids...',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Color(0xFF5C2D91),
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C2D91),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bid List ─────────────────────────────────────────────────────────────────

class _BidList extends StatelessWidget {
  final List<Bid> bids;
  final int? acceptingBidId;
  final Future<void> Function(Bid) onAccept;

  const _BidList({
    required this.bids,
    required this.acceptingBidId,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BiddingProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Bids sorted by price — tap Accept to confirm.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        ...bids.map((bid) => _BidCard(
              bid: bid,
              driverName: provider.driverName(bid.driverId),
              isAccepting: acceptingBidId == bid.id,
              isDisabled: acceptingBidId != null && acceptingBidId != bid.id,
              onAccept: () => onAccept(bid),
            )),
      ],
    );
  }
}

// ── Bid Card ─────────────────────────────────────────────────────────────────

class _BidCard extends StatelessWidget {
  final Bid bid;
  final String driverName;
  final bool isAccepting;
  final bool isDisabled;
  final VoidCallback onAccept;

  const _BidCard({
    required this.bid,
    required this.driverName,
    required this.isAccepting,
    required this.isDisabled,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final name = driverName;
    const rating = '4.8';
    const vehicle = 'Honda CD-70';
    final initial = name.substring(0, 1);

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
            // Driver avatar.
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF5C2D91),
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

            // Driver info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Fare + Accept button.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${bid.amount.toInt()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5C2D91),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 88,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: isDisabled ? null : onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C2D91),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: isAccepting
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
                                fontSize: 13, fontWeight: FontWeight.w700),
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
