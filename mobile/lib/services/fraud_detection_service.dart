import 'package:geolocator/geolocator.dart';
import '../models/claim.dart';
import '../utils/device_fingerprint.dart';
import 'api_service.dart';

class FraudCheckResult {
  final double score;       // 0.0–1.0
  final List<String> flags; // e.g. ['GPS_MISMATCH', 'BURST_CLAIMS', 'SHARED_DEVICE']
  final bool requiresReview;

  const FraudCheckResult({
    required this.score,
    required this.flags,
    required this.requiresReview,
  });

  factory FraudCheckResult.clean() =>
      const FraudCheckResult(score: 0, flags: [], requiresReview: false);

  factory FraudCheckResult.fromJson(Map<String, dynamic> j) {
    final score = ((j['fraudScore'] as num?) ?? 0).toDouble() / 100.0;
    final flags = (j['fraudFlags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return FraudCheckResult(
      score: score.clamp(0.0, 1.0),
      flags: flags,
      requiresReview: score > 0.5,
    );
  }
}

class FraudDetectionService {
  final ApiService _api;

  FraudDetectionService({ApiService? api}) : _api = api ?? ApiService();

  // ── Public entry point ───────────────────────────────────────────────────

  /// Runs all fraud checks for a claim submission.
  /// Returns a combined [FraudCheckResult] aggregated from:
  ///   1. Device fingerprint / ring check (server-side)
  ///   2. GPS verification (local + server)
  ///   3. The backend's existing assessClaimFraud logic (via claim submission)
  Future<FraudCheckResult> checkClaim(String riderId, Claim claim) async {
    final fingerprint = await DeviceFingerprint.collect();
    final flags = <String>[];
    double score = 0.0;

    // 1. Device fingerprint check
    final deviceResult = await _checkDevice(riderId, fingerprint);
    score += deviceResult.score;
    flags.addAll(deviceResult.flags);

    // 2. GPS verification
    final gpsResult = await _verifyGPS(claim);
    score += gpsResult.score;
    flags.addAll(gpsResult.flags);

    // 3. Cell tower / emulator simulation detection
    final simResult = _detectSimulation(fingerprint);
    score += simResult.score;
    flags.addAll(simResult.flags);

    final combined = score.clamp(0.0, 1.0);
    return FraudCheckResult(
      score: combined,
      flags: flags,
      requiresReview: combined > 0.5,
    );
  }

  // ── Device fingerprint check ─────────────────────────────────────────────

  Future<FraudCheckResult> _checkDevice(
    String riderId,
    Map<String, dynamic> fingerprint,
  ) async {
    try {
      final res = await _api.checkDevice({
        'riderId': riderId,
        'fingerprint': fingerprint,
      });
      if (res.success && res.data != null) {
        return FraudCheckResult.fromJson(res.data!);
      }
    } catch (_) {}
    return FraudCheckResult.clean();
  }

  // ── GPS verification ─────────────────────────────────────────────────────

  Future<FraudCheckResult> _verifyGPS(Claim claim) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return FraudCheckResult.clean();
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Haversine distance between current position and claim trigger location
      final distKm = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            claim.triggerData.lat,
            claim.triggerData.lng,
          ) /
          1000.0;

      if (distKm > 15) {
        return FraudCheckResult(
          score: 0.25,
          flags: ['GPS_MISMATCH:${distKm.toStringAsFixed(1)}km'],
          requiresReview: true,
        );
      } else if (distKm > 8) {
        return FraudCheckResult(
          score: 0.12,
          flags: ['GPS_DISTANCE_ELEVATED:${distKm.toStringAsFixed(1)}km'],
          requiresReview: false,
        );
      }
    } catch (_) {}
    return FraudCheckResult.clean();
  }

  // ── Emulator / cell-tower simulation detection ───────────────────────────

  FraudCheckResult _detectSimulation(Map<String, dynamic> fingerprint) {
    final isPhysical = fingerprint['isPhysicalDevice'] as bool? ?? true;
    if (!isPhysical) {
      return const FraudCheckResult(
        score: 0.4,
        flags: ['EMULATOR_DETECTED'],
        requiresReview: true,
      );
    }
    // Suspicious device identifiers used by cell-tower simulation tools
    final model = (fingerprint['model'] as String? ?? '').toLowerCase();
    final hardware = (fingerprint['hardware'] as String? ?? '').toLowerCase();
    const suspiciousTerms = ['generic', 'sdk', 'emulator', 'genymotion', 'vbox'];
    for (final term in suspiciousTerms) {
      if (model.contains(term) || hardware.contains(term)) {
        return FraudCheckResult(
          score: 0.3,
          flags: ['SUSPICIOUS_DEVICE_MODEL:$model'],
          requiresReview: true,
        );
      }
    }
    return FraudCheckResult.clean();
  }

  // ── Ring detection (shared device across riders) ─────────────────────────

  Future<bool> checkRingMembership(
      String deviceFingerprintId, String riderId) async {
    try {
      final res = await _api.checkRing({
        'clientFingerprintId': deviceFingerprintId,
        'riderId': riderId,
      });
      if (res.success && res.data != null) {
        return res.data!['isRingMember'] as bool? ?? false;
      }
    } catch (_) {}
    return false;
  }
}
