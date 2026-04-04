import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart';
import 'onboarding/onboarding_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;

    Widget destination;
    if (!loggedIn) {
      destination = const LoginScreen();
    } else {
      final onboarded = await StorageService().isOnboardingDone();
      destination =
          onboarded ? const HomeScreen() : const OnboardingWrapper();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: RainCheckTheme.primary.withAlpha(38),
                shape: BoxShape.circle,
                border: Border.all(color: RainCheckTheme.primary, width: 2),
              ),
              child: const Icon(
                Icons.water_drop,
                color: RainCheckTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RainCheck',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Parametric Insurance for Riders',
              style: TextStyle(
                color: RainCheckTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: RainCheckTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
