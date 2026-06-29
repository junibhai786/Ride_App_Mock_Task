import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/core/constants/app_constants.dart';
import 'package:ride_app_mock/providers/heatmap_provider.dart';
import 'package:ride_app_mock/widgets/legend_item.dart';

/// [HeatmapScreen] is a pure UI layer.
///
/// All HTTP fetching, auto-refresh timer, zone aggregation, and circle
/// building live in [HeatmapProvider]. This screen only reads state and
/// delegates actions to the provider.
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Start fetching + auto-refresh in the provider.
    context.read<HeatmapProvider>().init();
  }

  @override
  void dispose() {
    context.read<HeatmapProvider>().cleanup();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HeatmapProvider>();

    return Scaffold(
      // FAB to seed demo data for first-time testing.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isSeedLoading ? null : provider.seedData,
        backgroundColor: AppColors.primary,
        icon: provider.isSeedLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
        label: const Text(
          'Seed Demo Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          // Full-screen map — circles rendered once loading finishes.
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(
                  CameraUpdate.newLatLngZoom(AppConstants.lahore, 12));
            },
            initialCameraPosition: const CameraPosition(
              target: AppConstants.lahore,
              zoom: 12,
            ),
            // Delegate circle construction entirely to the provider.
            circles: provider.isLoading ? {} : provider.buildCircles(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Top bar: back button + status badge + optional surge badge.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
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
                  const SizedBox(width: 10),

                  // Status badge showing zone count and refresh interval.
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            provider.isLoading
                                ? 'Loading demand zones...'
                                : '${provider.zones.length} zones · auto-refresh 30s',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Surge active badge — only shown when at least one zone has surge.
                  if (provider.hasSurge) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'SURGE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Loading spinner centered on the map during the first fetch.
          if (provider.isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Error banner displayed when the fetch fails.
          if (provider.exception != null)
            Positioned(
              top: 90,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  provider.exception!.message,
                  style: TextStyle(fontSize: 13, color: Colors.red[700]),
                ),
              ),
            ),

          // Bottom legend card — zone counts and surge warning.
          if (!provider.isLoading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle.
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Demand Zones — Last 24 Hours',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkNavy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Three legend items for High / Medium / Low demand.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        LegendItem(
                          color: const Color(0xFFFF3232),
                          label: 'High',
                          count: provider.highCount,
                          description: 'Surge active',
                        ),
                        LegendItem(
                          color: const Color(0xFFFF9800),
                          label: 'Medium',
                          count: provider.mediumCount,
                          description: 'Rising demand',
                        ),
                        LegendItem(
                          color: const Color(0xFF50C878),
                          label: 'Low',
                          count: provider.lowCount,
                          description: 'Normal fare',
                        ),
                      ],
                    ),

                    // Surge warning row — only shown when surge zones exist.
                    if (provider.hasSurge) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                color: Colors.red[700], size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Surge pricing active — high-demand zones '
                                'charge up to 2× the base fare',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
