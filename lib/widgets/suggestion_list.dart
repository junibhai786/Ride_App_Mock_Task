import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';

/// [SuggestionList] renders a floating dropdown of Google Places autocomplete
/// results. Shows at most 5 rows to keep the dropdown compact.
class SuggestionList extends StatelessWidget {
  /// The raw predictions list from the Places Autocomplete API.
  final List<dynamic> suggestions;

  /// Called when the user taps a prediction row.
  final Future<void> Function(dynamic) onTap;

  const SuggestionList({
    super.key,
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        // Cap at 5 items to avoid an oversized dropdown.
        itemCount: suggestions.length > 5 ? 5 : suggestions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final prediction = suggestions[index];
          // Extract the primary name and secondary context from the Places API response.
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
                color: AppColors.primary, size: 20),
            title: Text(mainText,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: secondaryText.isNotEmpty
                ? Text(secondaryText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]))
                : null,
            onTap: () => onTap(prediction),
          );
        },
      ),
    );
  }
}
