import 'package:flutter/material.dart';

/// A single demand-level legend entry shown in the [HeatmapScreen] bottom card.
/// Displays a colored circle, a label, zone count, and a short description.
class LegendItem extends StatelessWidget {
  /// The color representing this demand level (red / orange / green).
  final Color color;

  /// Human-readable label: 'High', 'Medium', or 'Low'.
  final String label;

  /// Number of zones currently at this demand level.
  final int count;

  /// Short phrase explaining what this level means for pricing.
  final String description;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    required this.count,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Colored circle swatch.
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

        // Demand level label in the matching color.
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),

        // Zone count.
        Text(
          '$count zones',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),

        // Pricing description.
        Text(
          description,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
