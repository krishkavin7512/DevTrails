import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum CrashType { hardImpact, suddenStop }

class CrashEvent {
  final CrashType type;
  final double magnitude;
  final DateTime timestamp;
  const CrashEvent(
      {required this.type,
      required this.magnitude,
      required this.timestamp});
}

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _gpsSub;

  double _lastSpeed = 0; // m/s
  DateTime _lastSpeedTs = DateTime.now();

  // Debounce: don't fire crash twice within 5 s
  DateTime? _lastCrashTs;
  static const _debounce = Duration(seconds: 5);

  // 4G = 4 × 9.81 = 39.24 m/s²
  static const double _gThreshold = 39.24;

  Function(CrashEvent)? onCrashDetected;

  bool get isMonitoring => _accelSub != null;

  void startMonitoring({Function(CrashEvent)? onCrash}) {
    if (isMonitoring) return;
    onCrashDetected = onCrash;

    _accelSub = accelerometerEventStream().listen(_checkAccel);

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(_checkSpeed);
  }

  void stopMonitoring() {
    _accelSub?.cancel();
    _accelSub = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    onCrashDetected = null;
  }

  void _checkAccel(AccelerometerEvent e) {
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (mag > _gThreshold) _fire(CrashType.hardImpact, mag);
  }

  void _checkSpeed(Position pos) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSpeedTs).inMilliseconds / 1000.0;
    final curKmh = pos.speed * 3.6;
    final prevKmh = _lastSpeed * 3.6;

    // 40 km/h → <5 km/h in under 2 seconds
    if (prevKmh > 40 && curKmh < 5 && elapsed < 2) {
      _fire(CrashType.suddenStop, prevKmh);
    }

    _lastSpeed = pos.speed;
    _lastSpeedTs = now;
  }

  void _fire(CrashType type, double mag) {
    final now = DateTime.now();
    if (_lastCrashTs != null &&
        now.difference(_lastCrashTs!) < _debounce) {
      return;
    }
    _lastCrashTs = now;
    onCrashDetected?.call(
        CrashEvent(type: type, magnitude: mag, timestamp: now));
  }
}
