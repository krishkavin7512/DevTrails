import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceFingerprint {
  /// Collects comprehensive device information.
  /// SHA-256 hashing is deferred to the backend since dart:crypto is unavailable.
  /// [clientFingerprintId] is a base64-encoded lightweight client ID for quick dedup.
  static Future<Map<String, dynamic>> collect() async {
    final info = DeviceInfoPlugin();
    try {
      final android = await info.androidInfo;
      final fields = <String, dynamic>{
        'deviceId':          android.id,
        'model':             android.model,
        'manufacturer':      android.manufacturer,
        'brand':             android.brand,
        'board':             android.board,
        'hardware':          android.hardware,
        'display':           android.display,
        'host':              android.host,
        'androidVersion':    android.version.release,
        'sdkInt':            android.version.sdkInt,
        'isPhysicalDevice':  android.isPhysicalDevice,
      };
      // Lightweight client-side fingerprint (NOT cryptographically secure).
      // Backend computes SHA-256 from the raw fields for authoritative hashing.
      final raw = fields.entries.map((e) => '${e.key}=${e.value}').join('|');
      final clientFingerprintId = base64Url.encode(utf8.encode(raw));
      return {
        ...fields,
        'clientFingerprintId': clientFingerprintId,
      };
    } catch (_) {
      return {
        'deviceId':           'unknown',
        'isPhysicalDevice':   false,
        'clientFingerprintId': 'unknown',
      };
    }
  }

  /// Convenience: just the base64 client fingerprint string.
  static Future<String> fingerprintId() async {
    final data = await collect();
    return data['clientFingerprintId'] as String? ?? 'unknown';
  }
}
