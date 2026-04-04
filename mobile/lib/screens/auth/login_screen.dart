import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.cancelled) return;

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }

    if (result.isNewUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RegisterScreen(authResult: result)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _goToPhoneRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Logo row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: RainCheckTheme.primary.withAlpha(38),
                      shape: BoxShape.circle,
                      border: Border.all(color: RainCheckTheme.primary),
                    ),
                    child: const Icon(Icons.water_drop,
                        color: RainCheckTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'RainCheck',
                    style: TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              const Text(
                'Insurance that pays\nautomatically.',
                style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Parametric coverage for food delivery riders.\nNo claims. No paperwork. Just protection.',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 48),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RainCheckTheme.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: RainCheckTheme.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: RainCheckTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: RainCheckTheme.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Google Sign-In
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _handleGoogleSignIn,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.g_mobiledata,
                          size: 26, color: Colors.white),
                  label: Text(
                    _loading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RainCheckTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Phone Sign-In
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _goToPhoneRegister,
                  icon: const Icon(Icons.phone_android,
                      color: RainCheckTheme.textSecondary),
                  label: const Text(
                    'Continue with Phone',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: RainCheckTheme.textSecondary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: RainCheckTheme.surfaceVariant),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RainCheckTheme.textSecondary.withAlpha(150),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
