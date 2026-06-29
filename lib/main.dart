import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/providers/auth_provider.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/providers/driver_provider.dart';
import 'package:ride_app_mock/providers/heatmap_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';
import 'package:ride_app_mock/providers/tracking_provider.dart';
import 'package:ride_app_mock/screens/splash_screen.dart';

/// Entry point of the application.
/// Wraps the widget tree in [MultiProvider] to inject all business logic dependencies.
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Manages phone number registration, OTP sending, and verification.
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Manages ride fare fetching and Google Maps route rendering.
        ChangeNotifierProvider(create: (_) => RideProvider()),

        // Manages pickup/drop text inputs, place suggestions, and map markers.
        ChangeNotifierProvider(create: (_) => RideRequestProvider()),

        // Manages ride creation, driver bidding, and bid acceptance lifecycle.
        ChangeNotifierProvider(create: (_) => BiddingProvider()),

        // Manages driver GPS, socket broadcasting, and online/offline state.
        ChangeNotifierProvider(create: (_) => DriverProvider()),

        // Manages passenger-side socket tracking and driver simulation.
        ChangeNotifierProvider(create: (_) => TrackingProvider()),

        // Manages heatmap zone fetching, aggregation, and auto-refresh.
        ChangeNotifierProvider(create: (_) => HeatmapProvider()),
      ],
      child: const RideApp(),
    ),
  );
}

/// The root widget of the application.
class RideApp extends StatelessWidget {
  const RideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride App Mock',
      debugShowCheckedModeBanner: false,
      // Global theme built from the brand primary color.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      // App always starts at the animated Splash Screen.
      home: const SplashScreen(),
    );
  }
}
