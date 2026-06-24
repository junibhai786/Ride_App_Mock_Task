import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_app_mock/providers/auth_provider.dart';
import 'package:ride_app_mock/providers/ride_provider.dart';
import 'package:ride_app_mock/providers/ride_request_provider.dart';
import 'package:ride_app_mock/screens/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => RideRequestProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride App Mock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C2D91)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
