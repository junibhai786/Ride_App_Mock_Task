import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';

import 'ride_result_screen.dart';

class RequestRideScreen extends StatelessWidget {
  const RequestRideScreen({super.key});

  static const LatLng _lahore = LatLng(31.5204, 74.3587);

  void _findRide(BuildContext context) {
    final provider = context.read<RideRequestProvider>();
    final rideProvider = context.read<RideProvider>();

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
        itemCount: suggestions.length > 5 ? 5 : suggestions.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final prediction = suggestions[index];
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
                  // Improved Location Selection Card
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
                          // Left side: Route visualizer
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
                          // Right side: TextFields
                          Expanded(
                            child: Column(
                              children: [
                                // Pickup Field
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
                                // Drop Field
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

                  // Suggestions
                  if (provider.showPickupSuggestions &&
                      provider.pickupSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(
                          provider.pickupSuggestions, provider.selectPickup),
                    ),
                  if (provider.showDropSuggestions &&
                      provider.dropSuggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildSuggestionList(
                          provider.dropSuggestions, provider.selectDrop),
                    ),

                  const SizedBox(height: 24),

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
