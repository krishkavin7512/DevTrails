import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alert.dart';
import '../services/api_service.dart';
import '../services/sensor_service.dart';
import 'auth_provider.dart';

// ── Emergency state ───────────────────────────────────────────────────────

enum EmergencyPhase {
  idle,
  // Panic button UI phases
  longPressing, // user is long-pressing (0→3s)
  awaitingConfirm, // swipe-to-confirm slider shown
  countdown, // 5-second countdown before send
  // Active emergency
  active,
  // Crash detection
  crashDetected, // showing "are you okay?" modal (30s countdown)
}

class EmergencyState {
  final EmergencyPhase phase;
  final double longPressProgress; // 0.0 → 1.0 during longPress
  final int countdownSeconds; // 5 → 0
  final int crashCountdownSeconds; // 30 → 0
  final DateTime? activeSince;
  final double? lat;
  final double? lng;
  final String? emergencyId;
  final CrashEvent? lastCrash;
  final bool sending;
  final String? error;
  // Nearby riders who acknowledged
  final List<String> acknowledgedRiderIds;

  const EmergencyState({
    this.phase = EmergencyPhase.idle,
    this.longPressProgress = 0,
    this.countdownSeconds = 5,
    this.crashCountdownSeconds = 30,
    this.activeSince,
    this.lat,
    this.lng,
    this.emergencyId,
    this.lastCrash,
    this.sending = false,
    this.error,
    this.acknowledgedRiderIds = const [],
  });

  bool get isActive => phase == EmergencyPhase.active;
  bool get isCrashAlert => phase == EmergencyPhase.crashDetected;

  EmergencyState copyWith({
    EmergencyPhase? phase,
    double? longPressProgress,
    int? countdownSeconds,
    int? crashCountdownSeconds,
    DateTime? activeSince,
    double? lat,
    double? lng,
    String? emergencyId,
    CrashEvent? lastCrash,
    bool? sending,
    String? error,
    List<String>? acknowledgedRiderIds,
    bool clearError = false,
  }) =>
      EmergencyState(
        phase: phase ?? this.phase,
        longPressProgress: longPressProgress ?? this.longPressProgress,
        countdownSeconds: countdownSeconds ?? this.countdownSeconds,
        crashCountdownSeconds:
            crashCountdownSeconds ?? this.crashCountdownSeconds,
        activeSince: activeSince ?? this.activeSince,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        emergencyId: emergencyId ?? this.emergencyId,
        lastCrash: lastCrash ?? this.lastCrash,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
        acknowledgedRiderIds:
            acknowledgedRiderIds ?? this.acknowledgedRiderIds,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final Ref _ref;

  Timer? _longPressTimer;
  Timer? _countdownTimer;
  Timer? _crashCountdownTimer;
  Timer? _autoExpireTimer;
  Timer? _locationPollTimer;

  static const _countdownStart = 5;
  static const _crashCountdownStart = 30;
  static const _autoExpire = Duration(hours: 2);
  static const _locationPollInterval = Duration(seconds: 10);

  EmergencyNotifier(this._ref) : super(const EmergencyState()) {
    // Wire crash detection
    SensorService().startMonitoring(onCrash: _onCrashDetected);
  }

  @override
  void dispose() {
    _cancelAllTimers();
    SensorService().stopMonitoring();
    super.dispose();
  }

  // ── Long-press gesture ──────────────────────────────────────────────────

  void onLongPressStart() {
    if (state.phase != EmergencyPhase.idle) return;
    state = state.copyWith(
        phase: EmergencyPhase.longPressing, longPressProgress: 0);

    // Tick progress every 50ms
    int ticks = 0;
    const totalTicks = 60; // 3s / 50ms
    _longPressTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      ticks++;
      final progress = ticks / totalTicks;
      state = state.copyWith(longPressProgress: progress.clamp(0.0, 1.0));
      if (ticks >= totalTicks) {
        t.cancel();
        state = state.copyWith(
            phase: EmergencyPhase.awaitingConfirm, longPressProgress: 1.0);
      }
    });
  }

  void onLongPressCancel() {
    if (state.phase != EmergencyPhase.longPressing) return;
    _longPressTimer?.cancel();
    state = const EmergencyState();
  }

  // ── Swipe confirm ───────────────────────────────────────────────────────

  void onSwipeConfirmed() {
    if (state.phase != EmergencyPhase.awaitingConfirm) return;
    _startCountdown();
  }

  void cancelFromConfirm() {
    state = const EmergencyState();
  }

  // ── 5-second countdown ──────────────────────────────────────────────────

  void _startCountdown() {
    state = state.copyWith(
        phase: EmergencyPhase.countdown,
        countdownSeconds: _countdownStart);
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.countdownSeconds - 1;
      if (remaining <= 0) {
        t.cancel();
        _triggerEmergency(type: 'manual');
      } else {
        state = state.copyWith(countdownSeconds: remaining);
      }
    });
  }

  void cancelCountdown() {
    _countdownTimer?.cancel();
    state = const EmergencyState();
  }

  // ── Crash detection ─────────────────────────────────────────────────────

  void _onCrashDetected(CrashEvent event) {
    // Don't interrupt an already-active emergency
    if (state.isActive || state.isCrashAlert) return;
    state = state.copyWith(
        phase: EmergencyPhase.crashDetected,
        lastCrash: event,
        crashCountdownSeconds: _crashCountdownStart);
    _startCrashCountdown();
  }

  void _startCrashCountdown() {
    _crashCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = state.crashCountdownSeconds - 1;
      if (remaining <= 0) {
        t.cancel();
        _triggerEmergency(type: 'crash_detected');
      } else {
        state = state.copyWith(crashCountdownSeconds: remaining);
      }
    });
  }

  void respondImFine() {
    _crashCountdownTimer?.cancel();
    state = const EmergencyState();
  }

  void respondGetHelp() {
    _crashCountdownTimer?.cancel();
    _triggerEmergency(type: 'crash_detected');
  }

  // ── Trigger emergency ───────────────────────────────────────────────────

  Future<void> _triggerEmergency({required String type}) async {
    state = state.copyWith(sending: true, clearError: true);

    final riderId = _ref.read(authProvider).riderId ?? '';
    final pos = await _getCurrentPosition();

    final res = await ApiService().triggerEmergency({
      'riderId': riderId,
      'location': {'lat': pos?.latitude ?? 0, 'lng': pos?.longitude ?? 0},
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (!res.success) {
      state = state.copyWith(
          sending: false,
          phase: EmergencyPhase.idle,
          error: res.error ?? 'Failed to send emergency alert');
      return;
    }

    final emergencyId = (res.data?['emergencyId'] as String?) ?? '';
    state = state.copyWith(
      phase: EmergencyPhase.active,
      sending: false,
      activeSince: DateTime.now(),
      lat: pos?.latitude,
      lng: pos?.longitude,
      emergencyId: emergencyId,
    );

    _startLocationPolling();
    _scheduleAutoExpire();
  }

  // ── Active emergency helpers ────────────────────────────────────────────

  void _startLocationPolling() {
    _locationPollTimer =
        Timer.periodic(_locationPollInterval, (_) async {
      final pos = await _getCurrentPosition();
      if (pos != null && mounted) {
        state = state.copyWith(lat: pos.latitude, lng: pos.longitude);
        // Update backend with live location
        if (state.emergencyId != null) {
          ApiService().updateEmergencyLocation(state.emergencyId!, {
            'lat': pos.latitude,
            'lng': pos.longitude,
          });
        }
      }
    });
  }

  void _scheduleAutoExpire() {
    _autoExpireTimer = Timer(_autoExpire, () {
      if (state.isActive) cancelEmergency(autoExpired: true);
    });
  }

  Future<void> cancelEmergency({bool autoExpired = false}) async {
    if (!state.isActive) return;
    _cancelAllTimers();

    final id = state.emergencyId;
    if (id != null) {
      await ApiService().cancelEmergency(id,
          {'reason': autoExpired ? 'auto_expired' : 'rider_safe'});
    }

    state = const EmergencyState();
  }

  // ── Acknowledge (nearby rider) ──────────────────────────────────────────

  void addAcknowledgement(String riderId) {
    if (state.acknowledgedRiderIds.contains(riderId)) return;
    state = state.copyWith(
        acknowledgedRiderIds: [...state.acknowledgedRiderIds, riderId]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      return null;
    }
  }

  void _cancelAllTimers() {
    _longPressTimer?.cancel();
    _countdownTimer?.cancel();
    _crashCountdownTimer?.cancel();
    _autoExpireTimer?.cancel();
    _locationPollTimer?.cancel();
  }
}

final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>(
        (ref) => EmergencyNotifier(ref));

// Convenience: expose nearby alert list for acknowledged riders
final nearbyAlertsForEmergency =
    Provider<List<Alert>>((ref) => const []);
