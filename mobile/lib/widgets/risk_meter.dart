import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class RiskMeter extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final String label;
  const RiskMeter({super.key, required this.value, required this.label});

  Color get _color {
    if (value < 0.33) return RainCheckTheme.success;
    if (value < 0.66) return RainCheckTheme.warning;
    return RainCheckTheme.error;
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 70,
            child: CustomPaint(
              painter: _GaugePainter(value: value, color: _color),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: _color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.width / 2 - 8;

    final bgPaint = Paint()
      ..color = RainCheckTheme.surfaceVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi,
        math.pi,
        false,
        bgPaint);

    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi,
        math.pi * value,
        false,
        fgPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}
