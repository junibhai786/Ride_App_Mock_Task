import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// [HeatmapScreen] — Demand Zones feature.
/// Fetches aggregated pickup data from the backend (precision=2 grid, ~1 km cells)
/// and renders coloured Circle overlays on Google Maps.
/// Green = low demand, Orange = medium, Red = high / surge active.
/// Auto-refreshes every 30 s; Redis cache on the server means DB is hit at most
/// once per minute regardless of how many phones poll.
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  static const _serverUrl = 'http://10.176.23.172:3000';
  static const _lahore = LatLng(31.5204, 74.3587);

  GoogleMapController? _mapController;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  bool _isSeedLoading = false;
  String? _error;

  int _highCount = 0;
  int _mediumCount = 0;
  int _lowCount = 0;
  bool _hasSurge = false;

  @override
  void initState() {
    super.initState();
    _fetchZones();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _fetchZones());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchZones() async {
    try {
      final resp = await http
          .get(Uri.parse('$_serverUrl/api/heatmap/data'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final zones =
              (body['data'] as List).cast<Map<String, dynamic>>();

          int high = 0, medium = 0, low = 0;
          bool surge = false;
          for (final z in zones) {
            switch (z['demandLevel'] as String) {
              case 'high':
                high++;
                break;
              case 'medium':
                medium++;
                break;
              default:
                low++;
            }
            if ((z['surgeMultiplier'] as num) > 1.0) surge = true;
          }

          setState(() {
            _zones = zones;
            _highCount = high;
            _mediumCount = medium;
            _lowCount = low;
            _hasSurge = surge;
            _isLoading = false;
            _error = null;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Server returned an error. Is the backend running?';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Cannot reach server at $_serverUrl';
        });
      }
    }
  }

  // Calls POST /api/heatmap/seed to insert 500 dummy rides around Lahore,
  // then refreshes the map.
  Future<void> _seedData() async {
    setState(() => _isSeedLoading = true);
    try {
      await http
          .post(Uri.parse(
              '$_serverUrl/api/heatmap/seed?lat=31.5204&lng=74.3587&count=500'))
          .timeout(const Duration(seconds: 20));
      await _fetchZones();
    } catch (_) {}
    if (mounted) setState(() => _isSeedLoading = false);
  }

  // Build one semi-transparent Circle per zone; colour by demand level.
  Set<Circle> _buildCircles() {
    return _zones.asMap().entries.map((e) {
      final idx = e.key;
      final z = e.value;
      final lat = (z['lat'] as num).toDouble();
      final lng = (z['lng'] as num).toDouble();
      final level = z['demandLevel'] as String;

      Color fill, stroke;
      switch (level) {
        case 'high':
          fill = const Color(0x78FF3232);
          stroke = const Color(0xBBFF3232);
          break;
        case 'medium':
          fill = const Color(0x78FF9800);
          stroke = const Color(0xBBFF9800);
          break;
        default:
          fill = const Color(0x6050C878);
          stroke = const Color(0x9050C878);
      }

      return Circle(
        circleId: CircleId('z$idx'),
        center: LatLng(lat, lng),
        radius: 800, // metres — covers a ~1 km grid cell at precision=2
        fillColor: fill,
        strokeColor: stroke,
        strokeWidth: 1,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSeedLoading ? null : _seedData,
        backgroundColor: const Color(0xFF5C2D91),
        icon: _isSeedLoading
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
          // ── Full-screen map ────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.animateCamera(CameraUpdate.newLatLngZoom(_lahore, 12));
            },
            initialCameraPosition: const CameraPosition(
              target: _lahore,
              zoom: 12,
            ),
            circles: _isLoading ? {} : _buildCircles(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // ── Top bar ────────────────────────────────────────────────────────
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
                              size: 16, color: Color(0xFF5C2D91)),
                          const SizedBox(width: 6),
                          Text(
                            _isLoading
                                ? 'Loading demand zones...'
                                : '${_zones.length} zones · auto-refresh 30s',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_hasSurge) ...[
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

          // ── Loading spinner ────────────────────────────────────────────────
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C2D91)),
            ),

          // ── Error banner ───────────────────────────────────────────────────
          if (_error != null)
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
                  _error!,
                  style: TextStyle(fontSize: 13, color: Colors.red[700]),
                ),
              ),
            ),

          // ── Bottom legend card ─────────────────────────────────────────────
          if (!_isLoading)
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
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
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
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LegendItem(
                          color: const Color(0xFFFF3232),
                          label: 'High',
                          count: _highCount,
                          description: 'Surge active',
                        ),
                        _LegendItem(
                          color: const Color(0xFFFF9800),
                          label: 'Medium',
                          count: _mediumCount,
                          description: 'Rising demand',
                        ),
                        _LegendItem(
                          color: const Color(0xFF50C878),
                          label: 'Low',
                          count: _lowCount,
                          description: 'Normal fare',
                        ),
                      ],
                    ),
                    if (_hasSurge) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.red.shade200),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String description;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          '$count zones',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          description,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
