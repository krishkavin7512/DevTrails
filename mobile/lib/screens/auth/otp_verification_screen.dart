import 'package:flutter/material.dart';
import '../../core/theme.dart';

class OtpVerificationScreen extends StatelessWidget {
  const OtpVerificationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Verify OTP')),
        body: const Center(
          child: Text('OTP verification — coming in Prompt 2',
              style: TextStyle(color: RainCheckTheme.textSecondary)),
        ),
      );
}
