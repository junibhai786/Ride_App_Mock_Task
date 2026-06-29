import 'package:flutter/material.dart';
import 'package:ride_app_mock/core/constants/app_colors.dart';
import 'package:ride_app_mock/screens/driver_dashboard_screen.dart';
import 'package:ride_app_mock/screens/heatmap_screen.dart';
import 'package:ride_app_mock/screens/login_screen.dart';
import 'package:ride_app_mock/widgets/role_card.dart';

/// [RoleSelectScreen] lets the user choose their role — Passenger, Driver, or Heatmap viewer —
/// before entering the corresponding flow.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Dark-to-purple gradient matching the brand identity.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkNavy, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(),

                // App logo and tagline.
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'RideApp',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Who are you today?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),

                const Spacer(),

                // Passenger role — navigates to phone login.
                RoleCard(
                  icon: Icons.person_rounded,
                  title: 'Passenger',
                  subtitle: 'Request a ride and track your driver live',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                ),
                const SizedBox(height: 16),

                // Driver role — navigates directly to the driver dashboard.
                RoleCard(
                  icon: Icons.drive_eta_rounded,
                  title: 'Driver',
                  subtitle: 'Go online and share your location in real-time',
                  color: AppColors.driverBlue,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const DriverDashboardScreen(
                        driverId: 1,
                        driverName: 'Ahmed Ali',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Heatmap viewer — navigates to the demand zone map.
                RoleCard(
                  icon: Icons.layers_rounded,
                  title: 'Demand Heatmap',
                  subtitle:
                      'View real-time demand zones and surge pricing areas',
                  color: const Color(0xFF00897B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HeatmapScreen()),
                  ),
                ),

                const Spacer(),

                // Demo credentials hint for testers.
                Text(
                  'Driver credentials  ·  ID: 1  ·  Ahmed Ali',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
