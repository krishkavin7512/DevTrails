import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alert.dart';
import '../services/api_service.dart';

class MapState {
  final double? lat;
  final double? lng;
  final List<Alert> alerts;
  final bool locating;
  final bool loadingAlerts;
  final String? locationError;
  final DateTime? lastRefresh;

  const MapState({
    this.lat,
    this.lng,
    this.alerts = const [],
    this.locating = false,
    this.loadingAlerts = false,
    this.locationError,
    this.lastRefresh,
  });

  bool get hasLocation => lat != null && lng != null;

  MapState copyWith({
    double? lat,
    double? lng,
    List<Alert>? alerts,
    bool? locating,
    bool? loadingAlerts,
    String? locationError,
    DateTime? lastRefresh,
    bool clearLocationError = false,
  }) =>
      MapState(
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        alerts: alerts ?? this.alerts,
        locating: locating ?? this.locating,
        loadingAlerts: loadingAlerts ?? this.loadingAlerts,
        locationError:
            clearLocationError ? null : (locationError ?? this.locationError),
        lastRefresh: lastRefresh ?? this.lastRefresh,
      );
}

class MapNotifier extends StateNotifier<MapState> {
  Timer? _refreshTimer;
  static const _refreshInterval = Duration(seconds: 30);

  MapNotifier() : super(const MapState()) {
    _initialize();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _getLocation();
    _startAutoRefresh();
  }

  Future<void> _getLocation() async {
    state = state.copyWith(locating: true, clearLocationError: true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        // Fallback to Mumbai coords
        state = state.copyWith(
          lat: 19.0760,
          lng: 72.8777,
          locating: false,
          clearLocationError: true,
        );
        await _loadAlerts();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      state = state.copyWith(
        lat: pos.latitude,
        lng: pos.longitude,
        locating: false,
        clearLocationError: true,
      );
      await _loadAlerts();
    } catch (_) {
      // Fallback to Mumbai coords so map renders on emulator / GPS-denied devices
      state = state.copyWith(
        lat: 19.0760,
        lng: 72.8777,
        locating: false,
        clearLocationError: true,
      );
      await _loadAlerts();
    }
  }

  Future<void> _loadAlerts() async {
    if (!state.hasLocation) return;
    state = state.copyWith(loadingAlerts: true);
    try {
      final res = await ApiService().getNearbyAlerts(
        state.lat!,
        state.lng!,
        radius: 10.0,
      );
      state = state.copyWith(
        alerts: res.data ?? [],
        loadingAlerts: false,
        lastRefresh: DateTime.now(),
      );
    } catch (_) {
      state = state.copyWith(loadingAlerts: false);
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (!state.hasLocation) {
      await _getLocation();
    } else {
      await _loadAlerts();
    }
  }

  Future<void> retryLocation() => _getLocation();
}

final mapProvider =
    StateNotifierProvider<MapNotifier, MapState>((ref) => MapNotifier());
