import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Simple grid-based heatmap overlay for Google Maps.
/// Pass a list of (lat, lng, intensity) tuples.
class HeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> points;
  const HeatmapLayer({super.key, required this.points});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _HeatmapPainter(points: points)),
      );
}

class HeatmapPoint {
  final double x; // normalised 0-1 in widget space
  final double y;
  final double intensity; // 0-1

  const HeatmapPoint(
      {required this.x, required this.y, required this.intensity});
}

class _HeatmapPainter extends CustomPainter {
  final List<HeatmapPoint> points;
  _HeatmapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in points) {
      final color = Color.lerp(
        RainCheckTheme.success.withAlpha(80),
        RainCheckTheme.error.withAlpha(120),
        p.intensity,
      )!;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        30,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.points != points;
}
