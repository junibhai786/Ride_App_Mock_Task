import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';

import 'ride_result_screen.dart';

/// [RequestRideScreen] allows users to select pickup and drop-off locations
/// via interactive autocomplete text fields and view the map before requesting a ride.
class RequestRideScreen extends StatelessWidget {
  const RequestRideScreen({super.key});

  // Default initial map center coordinates targeting Lahore, Pakistan.
  static const LatLng _lahore = LatLng(31.5204, 74.3587);

  /// Validates inputs and prepares route details before navigating to the ride result screen.
  void _findRide(BuildContext context) {
    // Access Providers without listening to changes since this is a click callback.
    final provider = context.read<RideRequestProvider>();
    final rideProvider = context.read<RideProvider>();

    // Ensure both locations are selected by the user from suggestions.
    if (provider.pickupLatLng == null || provider.dropLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select both pickup and drop locations from the suggestions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set the selected route information inside the RideProvider.
    rideProvider.setRoute(
      provider.pickupLatLng!,
      provider.dropLatLng!,
      provider.pickupController.text,
      provider.dropController.text,
    );

    // Navigate to the screen showing available rides/drivers for the selected route.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RideResultScreen()),
    );
  }

  /// Builds a customized floating suggestions list overlay container for place suggestions.
  Widget _buildSuggestionList(
      List<dynamic> suggestions, Function(dynamic) onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Limits the suggestion list size up to 5 items maximum.
        itemCount: suggestions.length > 5 ? 5 : suggestions.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final prediction = suggestions[index];
          // Safely extract main title and secondary text from Google Places API structured response.
          final mainText =
              prediction['structured_formatting']?['main_text'] as String? ??
                  prediction['description'] as String;
          final secondaryText =
              prediction['structured_formatting']?['secondary_text']
                      as String? ??
                  '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on,
                color: Color(0xFF5C2D91), size: 20),
            title: Text(mainText,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: secondaryText.isNotEmpty
                ? Text(secondaryText,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]))
                : null,
            onTap: () => onTap(prediction),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for updates inside the RideRequestProvider to trigger rebuilds on location/suggestion state changes.
    final provider = context.watch<RideRequestProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Ride'),
        backgroundColor: const Color(0xFF5C2D91),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top portion displaying Google Maps with existing markers.
            SizedBox(
              height: 280,
              child: GoogleMap(
                onMapCreated: provider.setMapController,
                initialCameraPosition: const CameraPosition(
                  target: _lahore,
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
                  // Card UI containing Pickup and Drop Location input fields.
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
                          // Left visual connector indicating route path from pickup to drop point.
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
                          // Right side containing input forms for addressing locations.
                          Expanded(
                            child: Column(
                              children: [
                                // Input field for the pickup address.
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
                                // Input field for the destination address.
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

                  // Display suggestions dropdown container for the Pickup Field when requested.
                  if (provider.showPickupSuggestions &&
                      provider.pickupSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(
                          provider.pickupSuggestions, provider.selectPickup),
                    ),
                  // Display suggestions dropdown container for the Destination Field when requested.
                  if (provider.showDropSuggestions &&
                      provider.dropSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(
                          provider.dropSuggestions, provider.selectDrop),
                    ),

                  const SizedBox(height: 24),

                  // Button to initiate the route generation and find available matching rides.
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _findRide(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C2D91),
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
}
