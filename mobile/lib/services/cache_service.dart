import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple TTL-based JSON cache backed by SharedPreferences.
///
/// Keys used:
///   cache_weather_<city>        — 10-minute TTL
///   cache_claims_<riderId>      — 5-minute TTL
///   cache_dashboard_<riderId>   — 5-minute TTL
///   cache_policies_<riderId>    — 10-minute TTL
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const _ttls = {
    'weather':   Duration(minutes: 10),
    'claims':    Duration(minutes: 5),
    'dashboard': Duration(minutes: 5),
    'policies':  Duration(minutes: 10),
  };

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> set(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'v':  value,
    };
    await prefs.setString('cache_$key', json.encode(envelope));
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<T?> get<T>(String key, {Duration? ttl}) async {
    final prefs   = await SharedPreferences.getInstance();
    final raw     = prefs.getString('cache_$key');
    if (raw == null) return null;

    try {
      final envelope = json.decode(raw) as Map<String, dynamic>;
      final ts = envelope['ts'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - ts;

      // Resolve TTL: prefer explicit override, then key-prefix match, then 5 min.
      final resolvedTtl = ttl ?? _resolveTtl(key);
      if (age > resolvedTtl.inMilliseconds) {
        await prefs.remove('cache_$key');
        return null;
      }

      return envelope['v'] as T?;
    } catch (_) {
      return null;
    }
  }

  Duration _resolveTtl(String key) {
    for (final entry in _ttls.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    return const Duration(minutes: 5);
  }

  // ── Invalidate ─────────────────────────────────────────────────────────────

  Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
  }

  Future<void> invalidatePrefix(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys()
        .where((k) => k.startsWith('cache_$prefix'))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys()
        .where((k) => k.startsWith('cache_'))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  // ── Helpers for common keys ────────────────────────────────────────────────

  static String weatherKey(String city) => 'weather_$city';
  static String claimsKey(String riderId) => 'claims_$riderId';
  static String dashboardKey(String riderId) => 'dashboard_$riderId';
  static String policiesKey(String riderId) => 'policies_$riderId';
}
