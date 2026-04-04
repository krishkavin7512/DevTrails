import 'package:flutter/material.dart';
import '../core/theme.dart';

class FloatingAlertButton extends StatelessWidget {
  final VoidCallback onPressed;
  const FloatingAlertButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: RainCheckTheme.warning,
        icon: const Icon(Icons.warning_amber, color: Colors.white),
        label: const Text('Report Alert',
            style: TextStyle(color: Colors.white)),
      );
}
