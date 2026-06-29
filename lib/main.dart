import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/providers/auth_provider.dart';
import 'package:ride_app_mock/providers/bidding_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';
import 'package:ride_app_mock/screens/splash_screen.dart';

/// Entry point of the application.
/// It wraps the entire app in a MultiProvider to inject business logic dependencies.
void main() {
  runApp(
    MultiProvider(
      providers: [
        // Manages Authentication and OTP logic.
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Manages Ride search results and Route fetching logic.
        ChangeNotifierProvider(create: (_) => RideProvider()),
        // Manages Pickup/Drop location selection and suggestions logic.
        ChangeNotifierProvider(create: (_) => RideRequestProvider()),
        // Manages ride creation, driver bidding, and bid acceptance.
        ChangeNotifierProvider(create: (_) => BiddingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride App Mock',
      debugShowCheckedModeBanner: false,
      // Global theme configuration using the primary brand color.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C2D91)),
        useMaterial3: true,
      ),
      // App starts with the Splash Screen.
      home: const SplashScreen(),
    );
  }
}
