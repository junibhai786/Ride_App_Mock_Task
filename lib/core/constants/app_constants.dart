import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Application-wide configuration constants: API endpoints, keys, and coordinates.
/// Change values here once and they propagate everywhere automatically.
class AppConstants {
  // Prevent instantiation — this is a pure constants class.
  AppConstants._();

  /// Base URL of the Railway-hosted backend server.
  static const String serverUrl =
      'https://welcoming-mindfulness-production-539a.up.railway.app';

  /// Google Maps Platform API key — used for Maps, Places, and Directions APIs.
  static const String googleMapsApiKey =
      'AIzaSyBiA_0nQ8UDLzi6uJ444825ZOoCi_-SHBc';

  /// Default map center — Liberty Chowk, Lahore, Pakistan.
  static const LatLng lahore = LatLng(31.5204, 74.3587);
}
