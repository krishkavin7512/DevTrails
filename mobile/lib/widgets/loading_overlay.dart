import 'package:flutter/material.dart';
import '../core/theme.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  const LoadingOverlay(
      {super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (isLoading)
            const ColoredBox(
              color: Color(0x80000000),
              child: Center(
                child: CircularProgressIndicator(
                    color: RainCheckTheme.primary),
              ),
            ),
        ],
      );
}
