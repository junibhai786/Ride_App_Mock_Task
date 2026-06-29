import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';
import 'package:ride_app_mock/screens/ride_result_screen.dart';
import 'package:ride_app_mock/widgets/suggestion_list.dart';

/// [RequestRideScreen] lets passengers select their pickup and drop-off locations
/// via Google Places autocomplete, then confirms the route before searching for drivers.
class RequestRideScreen extends StatelessWidget {
  const RequestRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch for suggestion and marker state changes in the provider.
    final provider = context.watch<RideRequestProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Ride'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map preview at the top showing selected pickup/drop markers.
            SizedBox(
              height: 280,
              child: GoogleMap(
                onMapCreated: provider.setMapController,
                initialCameraPosition: const CameraPosition(
                  target: AppConstants.lahore,
                  zoom: 13,
                ),
                markers: provider.markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location input card with a visual route connector on the left.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Vertical connector: green dot → line → red pin.
                          Column(
                            children: [
                              const Icon(Icons.radio_button_checked,
                                  color: Colors.green, size: 20),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const Icon(Icons.location_on,
                                  color: Colors.red, size: 20),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Pickup and drop text fields stacked vertically.
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: provider.pickupController,
                                  decoration: const InputDecoration(
                                    hintText: 'Pickup Location',
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onChanged: provider.onPickupChanged,
                                  onTap: provider.showPickupSuggestionList,
                                ),
                                Divider(height: 1, color: Colors.grey[200]),
                                TextField(
                                  controller: provider.dropController,
                                  decoration: const InputDecoration(
                                    hintText: 'Drop Location',
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onChanged: provider.onDropChanged,
                                  onTap: provider.showDropSuggestionList,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pickup autocomplete suggestions dropdown.
                  if (provider.showPickupSuggestions &&
                      provider.pickupSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SuggestionList(
                        suggestions: provider.pickupSuggestions,
                        onTap: provider.selectPickup,
                      ),
                    ),

                  // Drop autocomplete suggestions dropdown.
                  if (provider.showDropSuggestions &&
                      provider.dropSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SuggestionList(
                        suggestions: provider.dropSuggestions,
                        onTap: provider.selectDrop,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Find Ride button — validates and navigates to RideResultScreen.
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _findRide(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Find Ride',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Validates that both locations are selected, then sets the route and navigates forward.
  void _findRide(BuildContext context) {
    final provider = context.read<RideRequestProvider>();
    final rideProvider = context.read<RideProvider>();

    // Guard: both pins must have resolved coordinates before we can draw a route.
    if (provider.pickupLatLng == null || provider.dropLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both pickup and drop locations from the suggestions.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Push the selected route into RideProvider so RideResultScreen can render it.
    rideProvider.setRoute(
      provider.pickupLatLng!,
      provider.dropLatLng!,
      provider.pickupController.text,
      provider.dropController.text,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RideResultScreen()),
    );
  }
}
