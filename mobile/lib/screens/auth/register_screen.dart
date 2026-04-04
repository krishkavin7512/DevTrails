import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import '../onboarding/onboarding_wrapper.dart';

/// Handles two entry paths:
///   1. Phone path  (authResult == null) — phone input → OTP → profile form
///   2. Google path (authResult != null, isNewUser) — skip to profile form
class RegisterScreen extends ConsumerStatefulWidget {
  final AuthResult? authResult;

  const RegisterScreen({super.key, this.authResult});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Step: 0 = phone, 1 = OTP, 2 = profile form
  int _step = 0;
  bool _loading = false;
  String? _error;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  String _platform = 'Zomato';
  String _vehicleType = 'Scooter';
  String _city = 'Mumbai';

  static const _cities = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow'];

  static const _cityCoords = {
    'Mumbai':    {'lat': 19.0760, 'lng': 72.8777},
    'Delhi':     {'lat': 28.6139, 'lng': 77.2090},
    'Bangalore': {'lat': 12.9716, 'lng': 77.5946},
    'Chennai':   {'lat': 13.0827, 'lng': 80.2707},
    'Hyderabad': {'lat': 17.3850, 'lng': 78.4867},
    'Kolkata':   {'lat': 22.5726, 'lng': 88.3639},
    'Pune':      {'lat': 18.5204, 'lng': 73.8567},
    'Ahmedabad': {'lat': 23.0225, 'lng': 72.5714},
    'Jaipur':    {'lat': 26.9124, 'lng': 75.7873},
    'Lucknow':   {'lat': 26.8467, 'lng': 80.9462},
  };

  AuthResult? _verifiedResult;

  @override
  void initState() {
    super.initState();
    if (widget.authResult != null && widget.authResult!.isNewUser) {
      _verifiedResult = widget.authResult;
      _step = 2;
      if (widget.authResult!.displayName != null) {
        _nameController.text = widget.authResult!.displayName!;
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).sendOTP(phone);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success || result.otpSent) {
      setState(() => _step = 1);
    } else {
      setState(() => _error = result.error ?? 'Failed to send OTP');
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authProvider.notifier).verifyOTP(otp);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Invalid OTP');
      return;
    }

    if (!result.isNewUser && result.riderId != null) {
      // Existing rider — straight to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // New user — collect profile
      _verifiedResult = result;
      if (result.phone != null) {
        _phoneController.text = result.phone!;
      }
      setState(() => _step = 2);
    }
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required');
      return;
    }
    if (_city.isEmpty) {
      setState(() => _error = 'City is required');
      return;
    }
    final phone = _verifiedResult?.phone ?? _phoneController.text.trim();
    if (phone.isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit phone number');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final rawPhone = _verifiedResult?.phone ?? _phoneController.text.trim();
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = digitsOnly.startsWith('91') && digitsOnly.length == 12
        ? digitsOnly.substring(2)
        : digitsOnly;

    final data = {
      'fullName': _nameController.text.trim(),
      'phone': formattedPhone,
      if (_verifiedResult?.email != null) 'email': _verifiedResult!.email,
      'city': _city,
      'platform': _platform,
      'vehicleType': _vehicleType,
      'operatingZone': _city,
      'operatingPincode': '600001',
      'avgWeeklyEarnings': 400000,
      'avgDailyHours': 8,
      'preferredShift': 'Morning',
      'experienceMonths': 6,
      'location': _cityCoords[_city] ?? {'lat': 19.0760, 'lng': 72.8777},
    };

    final result = await ref.read(authProvider.notifier).registerRider(data);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Registration failed');
      return;
    }

    // Seed onboarding provider with registration data so Step 1 is pre-filled
    ref.read(onboardingProvider.notifier).initFromRegistration(
          fullName: _nameController.text.trim(),
          city: _city,
          platform: _platform,
          vehicleType: _vehicleType,
        );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: Text(_step == 0
            ? 'Phone Number'
            : _step == 1
                ? 'Verify OTP'
                : 'Create Profile'),
        leading: _step > 0 && widget.authResult == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _step--;
                  _error = null;
                }),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? RainCheckTheme.primary
                            : RainCheckTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (_step == 0) _buildPhoneStep(),
              if (_step == 1) _buildOTPStep(),
              if (_step == 2) _buildProfileStep(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RainCheckTheme.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: RainCheckTheme.error.withAlpha(80)),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your phone number',
            style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text("We'll send a one-time code to verify",
            style:
                TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 28),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          autofocus: true,
          style: const TextStyle(
              color: RainCheckTheme.textPrimary, fontSize: 18),
          decoration: const InputDecoration(
            prefixText: '+91  ',
            prefixStyle:
                TextStyle(color: RainCheckTheme.textSecondary, fontSize: 18),
            hintText: '9876543210',
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton('Send OTP', _sendOTP),
      ],
    );
  }

  Widget _buildOTPStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter OTP',
            style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Sent to +91 ${_phoneController.text}',
            style: const TextStyle(
                color: RainCheckTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 28),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          style: const TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 24,
              letterSpacing: 8),
          decoration: const InputDecoration(
              counterText: '', hintText: '------'),
        ),
        const SizedBox(height: 24),
        _primaryButton('Verify & Continue', _verifyOTP),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _step = 0;
                      _error = null;
                      _otpController.clear();
                    }),
            child: const Text('Change number',
                style: TextStyle(color: RainCheckTheme.textSecondary)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick setup',
            style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Just a few details to get you started',
            style:
                TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 28),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Full Name',
            labelStyle: TextStyle(color: RainCheckTheme.textSecondary),
          ),
        ),
        if (_verifiedResult?.phone == null) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              labelStyle: TextStyle(color: RainCheckTheme.textSecondary),
              prefixText: '+91  ',
              prefixStyle: TextStyle(color: RainCheckTheme.textSecondary),
              hintText: '9876543210',
            ),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_city),
          initialValue: _city,
          dropdownColor: RainCheckTheme.surface,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'City',
            labelStyle: TextStyle(color: RainCheckTheme.textSecondary),
          ),
          items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _city = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_platform),
          initialValue: _platform,
          dropdownColor: RainCheckTheme.surface,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Platform',
            labelStyle: TextStyle(color: RainCheckTheme.textSecondary),
          ),
          items: ['Zomato', 'Swiggy', 'Both']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _platform = v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(_vehicleType),
          initialValue: _vehicleType,
          dropdownColor: RainCheckTheme.surface,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Vehicle Type',
            labelStyle: TextStyle(color: RainCheckTheme.textSecondary),
          ),
          items: ['Bicycle', 'Scooter', 'Motorcycle']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() => _vehicleType = v!),
        ),
        const SizedBox(height: 32),
        _primaryButton('Create Account', _register),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: RainCheckTheme.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
      ),
    );
  }
}
