import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/models/bid.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/widgets/bid_card.dart';

/// Renders the scrollable list of driver bids on [BiddingScreen].
/// Each bid is displayed as a [BidCard].
class BidList extends StatelessWidget {
  final List<Bid> bids;

  /// The ID of the bid currently being accepted, or null if none.
  final int? acceptingBidId;

  /// Callback invoked when the passenger taps Accept on a bid.
  final Future<void> Function(Bid) onAccept;

  const BidList({
    super.key,
    required this.bids,
    required this.acceptingBidId,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    // Read provider once — no need to listen since the list is passed explicitly.
    final provider = context.read<BiddingProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Instructional hint text above the bid cards.
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Bids sorted by price — tap Accept to confirm.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),

        // One BidCard per incoming driver bid.
        ...bids.map(
          (bid) => BidCard(
            bid: bid,
            driverName: provider.driverName(bid.driverId),
            isAccepting: acceptingBidId == bid.id,
            // Disable all other cards once one is being accepted.
            isDisabled:
                acceptingBidId != null && acceptingBidId != bid.id,
            onAccept: () => onAccept(bid),
          ),
        ),
      ],
    );
  }
}
