import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CrashDetector {
  static const _threshold = 20.0; // m/s² — tune as needed
  static const _confirmDelay = Duration(seconds: 8);

  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _confirmTimer;
  final VoidCallback onCrashConfirmed;

  CrashDetector({required this.onCrashConfirmed});

  void start() {
    _sub = accelerometerEventStream().listen((e) {
      final mag = e.x * e.x + e.y * e.y + e.z * e.z;
      if (mag > _threshold * _threshold && _confirmTimer == null) {
        _confirmTimer = Timer(_confirmDelay, () {
          onCrashConfirmed();
          _confirmTimer = null;
        });
      }
    });
  }

  void cancelPendingAlert() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
  }

  void stop() {
    _sub?.cancel();
    cancelPendingAlert();
  }
}
