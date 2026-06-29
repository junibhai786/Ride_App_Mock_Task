import 'package:flutter/material.dart';

/// Central color palette for the RideApp brand.
/// Import this file instead of writing raw hex values anywhere in the UI.
class AppColors {
  // Prevent instantiation — this is a pure constants class.
  AppColors._();

  /// Primary brand purple — used for buttons, AppBars, and highlights.
  static const Color primary = Color(0xFF5C2D91);

  /// Lighter purple — used in gradient backgrounds alongside [primary].
  static const Color primaryLight = Color(0xFF9C27B0);

  /// Deep navy — used for headings and body text on light surfaces.
  static const Color darkNavy = Color(0xFF1A1A2E);

  /// Blue accent — used exclusively for driver-role UI elements.
  static const Color driverBlue = Color(0xFF1565C0);

  /// Off-white surface — used as screen and card backgrounds.
  static const Color surface = Color(0xFFF7F7FC);
}
