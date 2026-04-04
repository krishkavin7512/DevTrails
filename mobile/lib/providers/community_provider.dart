import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'map_provider.dart';

// ── Offline queue ─────────────────────────────────────────────────────────

class QueuedAlert {
  final String type;
  final String description;
  final double lat;
  final double lng;
  final DateTime queuedAt;
  QueuedAlert({
    required this.type,
    required this.description,
    required this.lat,
    required this.lng,
    required this.queuedAt,
  });
}

// ── Community state ───────────────────────────────────────────────────────

class CommunityState {
  final List<Alert> nearbyAlerts;
  final TrustProfile? trustProfile;
  final bool loadingAlerts;
  final bool loadingTrust;
  final bool submitting;
  final String? submitError;
  final String? submitSuccess;
  // Rate limiting: timestamps of submissions this hour
  final List<DateTime> recentSubmissions;
  // Offline queue
  final List<QueuedAlert> offlineQueue;

  const CommunityState({
    this.nearbyAlerts = const [],
    this.trustProfile,
    this.loadingAlerts = false,
    this.loadingTrust = false,
    this.submitting = false,
    this.submitError,
    this.submitSuccess,
    this.recentSubmissions = const [],
    this.offlineQueue = const [],
  });

  bool get canSubmit {
    final now = DateTime.now();
    final recent = recentSubmissions
        .where((t) => now.difference(t) < const Duration(hours: 1))
        .length;
    return recent < 3;
  }

  int get submissionsThisHour {
    final now = DateTime.now();
    return recentSubmissions
        .where((t) => now.difference(t) < const Duration(hours: 1))
        .length;
  }

  CommunityState copyWith({
    List<Alert>? nearbyAlerts,
    TrustProfile? trustProfile,
    bool? loadingAlerts,
    bool? loadingTrust,
    bool? submitting,
    String? submitError,
    String? submitSuccess,
    List<DateTime>? recentSubmissions,
    List<QueuedAlert>? offlineQueue,
    bool clearSubmitError = false,
    bool clearSubmitSuccess = false,
  }) =>
      CommunityState(
        nearbyAlerts: nearbyAlerts ?? this.nearbyAlerts,
        trustProfile: trustProfile ?? this.trustProfile,
        loadingAlerts: loadingAlerts ?? this.loadingAlerts,
        loadingTrust: loadingTrust ?? this.loadingTrust,
        submitting: submitting ?? this.submitting,
        submitError: clearSubmitError ? null : (submitError ?? this.submitError),
        submitSuccess:
            clearSubmitSuccess ? null : (submitSuccess ?? this.submitSuccess),
        recentSubmissions: recentSubmissions ?? this.recentSubmissions,
        offlineQueue: offlineQueue ?? this.offlineQueue,
      );
}

// ── Trust profile ─────────────────────────────────────────────────────────

class TrustProfile {
  final int trustScore; // 0-100
  final String trustTier; // TrustedReporter | Normal | LowTrust
  final int totalPoints;
  final int alertsSubmitted;
  final int alertsConfirmed;
  final int alertsVerified;
  final List<TrustEvent> recentEvents;

  const TrustProfile({
    required this.trustScore,
    required this.trustTier,
    required this.totalPoints,
    required this.alertsSubmitted,
    required this.alertsConfirmed,
    required this.alertsVerified,
    required this.recentEvents,
  });

  factory TrustProfile.fromJson(Map<String, dynamic> j) => TrustProfile(
        trustScore: (j['trustScore'] ?? 50) as int,
        trustTier: j['trustTier'] ?? 'Normal',
        totalPoints: (j['totalPoints'] ?? 0) as int,
        alertsSubmitted: (j['alertsSubmitted'] ?? 0) as int,
        alertsConfirmed: (j['alertsConfirmed'] ?? 0) as int,
        alertsVerified: (j['alertsVerified'] ?? 0) as int,
        recentEvents: (j['recentEvents'] as List? ?? [])
            .map((e) => TrustEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Fallback: compute local trust profile from nearby alerts list
  factory TrustProfile.localFallback(String riderId, List<Alert> alerts) {
    final mine = alerts.where((a) => a.riderId == riderId).toList();
    final confirmed = mine.where((a) => a.confirmations >= 3).length;
    final verified = mine.where((a) => a.verified).length;
    final score = (50 + (verified * 5) + (confirmed * 2)).clamp(0, 100);
    final tier = score >= 75
        ? 'TrustedReporter'
        : score >= 40
            ? 'Normal'
            : 'LowTrust';
    return TrustProfile(
      trustScore: score,
      trustTier: tier,
      totalPoints: verified * 15 + confirmed * 5,
      alertsSubmitted: mine.length,
      alertsConfirmed: confirmed,
      alertsVerified: verified,
      recentEvents: const [],
    );
  }
}

class TrustEvent {
  final String description;
  final int delta; // positive or negative
  final DateTime at;
  TrustEvent({required this.description, required this.delta, required this.at});
  factory TrustEvent.fromJson(Map<String, dynamic> j) => TrustEvent(
        description: j['description'] ?? '',
        delta: (j['delta'] ?? 0) as int,
        at: DateTime.tryParse(j['at'] ?? '') ?? DateTime.now(),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class CommunityNotifier extends StateNotifier<CommunityState> {
  final Ref _ref;
  static const _rateKey = 'alert_submission_times';

  CommunityNotifier(this._ref) : super(const CommunityState()) {
    _loadRateHistory();
  }

  Future<void> _loadRateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_rateKey) ?? [];
    final now = DateTime.now();
    final times = raw
        .map((s) => DateTime.tryParse(s))
        .whereType<DateTime>()
        .where((t) => now.difference(t) < const Duration(hours: 2))
        .toList();
    state = state.copyWith(recentSubmissions: times);
  }

  Future<void> _saveRateHistory(List<DateTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final trimmed =
        times.where((t) => now.difference(t) < const Duration(hours: 2)).toList();
    await prefs.setStringList(
        _rateKey, trimmed.map((t) => t.toIso8601String()).toList());
  }

  Future<void> loadNearbyAlerts({double? lat, double? lng}) async {
    final mapState = _ref.read(mapProvider);
    final useLat = lat ?? mapState.lat ?? 0;
    final useLng = lng ?? mapState.lng ?? 0;

    state = state.copyWith(loadingAlerts: true);
    final res = await ApiService().getNearbyAlerts(useLat, useLng, radius: 10);
    final alerts = res.data ?? [];
    state = state.copyWith(loadingAlerts: false, nearbyAlerts: alerts);

    // Derive trust profile from alerts if no backend trust endpoint
    final riderId = _ref.read(authProvider).riderId;
    if (riderId != null) {
      _loadTrustProfile(riderId, alerts);
    }
  }

  Future<void> _loadTrustProfile(
      String riderId, List<Alert> alerts) async {
    state = state.copyWith(loadingTrust: true);
    // Try dedicated trust endpoint; fall back to local computation
    final res = await ApiService().getRiderTrustProfile(riderId);
    if (res.success && res.data != null) {
      state = state.copyWith(
          loadingTrust: false,
          trustProfile: TrustProfile.fromJson(res.data!));
    } else {
      state = state.copyWith(
          loadingTrust: false,
          trustProfile: TrustProfile.localFallback(riderId, alerts));
    }
  }

  Future<bool> submitAlert({
    required String type,
    required String description,
    required double lat,
    required double lng,
    required double locationAccuracy,
    required String riderId,
  }) async {
    // Rate limit check
    if (!state.canSubmit) {
      state = state.copyWith(
          submitError:
              'Max 3 alerts per hour. Try again in a bit.',
          clearSubmitSuccess: true);
      return false;
    }

    state = state.copyWith(
        submitting: true,
        clearSubmitError: true,
        clearSubmitSuccess: true);

    final payload = {
      'riderId': riderId,
      'type': type,
      'description': description,
      'location': {'lat': lat, 'lng': lng},
      'locationAccuracy': locationAccuracy,
    };

    final res = await ApiService().submitAlert(payload);

    if (!res.success) {
      // Offline queue
      final queued = [
        ...state.offlineQueue,
        QueuedAlert(
            type: type,
            description: description,
            lat: lat,
            lng: lng,
            queuedAt: DateTime.now()),
      ];
      state = state.copyWith(
          submitting: false,
          offlineQueue: queued,
          submitSuccess:
              'Saved offline. Will send when connection is restored.');
      return true;
    }

    final newAlert = res.data;
    final updatedAlerts = newAlert != null
        ? [newAlert, ...state.nearbyAlerts]
        : state.nearbyAlerts;

    final updatedTimes = [...state.recentSubmissions, DateTime.now()];
    await _saveRateHistory(updatedTimes);

    state = state.copyWith(
        submitting: false,
        nearbyAlerts: updatedAlerts,
        recentSubmissions: updatedTimes,
        submitSuccess: 'Alert reported! Awaiting confirmation from nearby riders.');

    // Refresh map
    _ref.read(mapProvider.notifier).refresh();

    return true;
  }

  Future<bool> confirmAlert(String alertId) async {
    final res = await ApiService().confirmAlert(alertId);
    if (!res.success) return false;

    final updated = state.nearbyAlerts.map((a) {
      if (a.id == alertId && res.data != null) return res.data!;
      return a;
    }).toList();

    state = state.copyWith(nearbyAlerts: updated);
    // Refresh trust (confirmations may affect reporter's score)
    final riderId = _ref.read(authProvider).riderId;
    if (riderId != null) _loadTrustProfile(riderId, updated);
    return true;
  }

  Future<void> flushOfflineQueue() async {
    if (state.offlineQueue.isEmpty) return;
    final riderId = _ref.read(authProvider).riderId;
    if (riderId == null) return;

    final remaining = <QueuedAlert>[];
    for (final q in state.offlineQueue) {
      final res = await ApiService().submitAlert({
        'riderId': riderId,
        'type': q.type,
        'description': q.description,
        'location': {'lat': q.lat, 'lng': q.lng},
      });
      if (!res.success) remaining.add(q);
    }
    state = state.copyWith(offlineQueue: remaining);
    if (remaining.length < state.offlineQueue.length) {
      _ref.read(mapProvider.notifier).refresh();
    }
  }
}

final communityProvider =
    StateNotifierProvider<CommunityNotifier, CommunityState>(
        (ref) => CommunityNotifier(ref));
