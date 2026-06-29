import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/screens/bidding_screen.dart';

/// [RideResultScreen] shows the selected route on a full-screen map and
/// presents a ride option (Bike) with fare and ETA before the passenger confirms.
class RideResultScreen extends StatelessWidget {
  const RideResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rideProvider = context.watch<RideProvider>();
    final pickupLatLng = rideProvider.pickupLatLng;
    final dropLatLng = rideProvider.dropLatLng;
    final pickupText = rideProvider.pickupText;
    final dropText = rideProvider.dropText;

    // Show a loading indicator while coordinates are being resolved.
    if (pickupLatLng == null || dropLatLng == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // Green pickup marker and red drop marker.
    final markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: pickupText),
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: dropLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Drop', snippet: dropText),
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map with route polyline drawn by RideProvider.
          GoogleMap(
            onMapCreated: context.read<RideProvider>().setMapController,
            initialCameraPosition: CameraPosition(
              target: pickupLatLng,
              zoom: 13,
            ),
            markers: markers,
            polylines: rideProvider.polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Floating back button overlaid on the top-left of the map.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 18),
                ),
              ),
            ),
          ),

          // Loading spinner while the Directions API polyline is being fetched.
          if (rideProvider.isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Draggable bottom sheet containing ride options and confirm button.
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    // Drag handle visual indicator.
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const Text(
                      'Driver Found!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ride type card: Bike with hardcoded fare and ETA.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Bike icon circle.
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_bike,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Vehicle type and description.
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bike',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Economy · 2-wheeler',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Fare and ETA on the right.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Rs. 180',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'ETA 4 min',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Route summary: pickup above, drop below, connected by a line.
                    Row(
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.circle,
                                color: Colors.green, size: 12),
                            Container(
                              width: 2,
                              height: 28,
                              color: Colors.grey[300],
                            ),
                            const Icon(Icons.location_on,
                                color: Colors.red, size: 16),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickupText,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                dropText,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Confirm Ride button — creates the ride and enters the bidding flow.
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          final rideProvider = context.read<RideProvider>();
                          // Kick off the bidding lifecycle on the backend.
                          context.read<BiddingProvider>().createRide(
                                rideProvider.pickupLatLng!,
                                rideProvider.dropLatLng!,
                              );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BiddingScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Confirm Ride',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
