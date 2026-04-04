import 'package:flutter/material.dart';
import '../../core/theme.dart';

class TriggersMonitorScreen extends StatelessWidget {
  const TriggersMonitorScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Live Triggers')),
        body: const Center(
          child: Text('Real-time trigger monitor — coming in Prompt 6',
              style: TextStyle(color: RainCheckTheme.textSecondary)),
        ),
      );
}
