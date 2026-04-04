import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'rider_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum AlertSeverity { low, medium, high, critical }

class PredictiveAlert {
  final String id;
  final String triggerType;   // HeavyRain | ExtremeHeat | SevereAQI | Flooding
  final String description;
  final DateTime predictedAt; // When the event is expected
  final DateTime alertedAt;   // When alert was generated
  final double confidence;    // 0–1
  final double predictedValue;
  final double threshold;
  final AlertSeverity severity;
  final bool dismissed;

  const PredictiveAlert({
    required this.id,
    required this.triggerType,
    required this.description,
    required this.predictedAt,
    required this.alertedAt,
    required this.confidence,
    required this.predictedValue,
    required this.threshold,
    required this.severity,
    this.dismissed = false,
  });

  String get hoursUntil {
    final h = predictedAt.difference(DateTime.now()).inHours;
    if (h <= 0) return 'Imminent';
    if (h < 24) return 'In ${h}h';
    return 'In ${predictedAt.difference(DateTime.now()).inDays}d';
  }

  String get confidenceLabel => '${(confidence * 100).toStringAsFixed(0)}%';

  PredictiveAlert copyWith({bool? dismissed}) => PredictiveAlert(
        id: id,
        triggerType: triggerType,
        description: description,
        predictedAt: predictedAt,
        alertedAt: alertedAt,
        confidence: confidence,
        predictedValue: predictedValue,
        threshold: threshold,
        severity: severity,
        dismissed: dismissed ?? this.dismissed,
      );
}

// ── OWM thresholds (must match backend trigger thresholds) ────────────────────

const _thresholds = {
  'HeavyRain':   50.0,  // mm/3h
  'ExtremeHeat': 40.0,  // °C
  'SevereAQI':   200.0, // AQI index (approximated from OWM visibility / clouds)
  'Flooding':    80.0,  // mm/3h (extreme)
};

// ── State ─────────────────────────────────────────────────────────────────────

class ForecastState {
  final List<PredictiveAlert> alerts;
  final bool loading;
  final String? error;
  final DateTime? lastFetched;

  const ForecastState({
    this.alerts = const [],
    this.loading = false,
    this.error,
    this.lastFetched,
  });

  int get activeCount =>
      alerts.where((a) => !a.dismissed && a.confidence >= 0.8).length;

  ForecastState copyWith({
    List<PredictiveAlert>? alerts,
    bool? loading,
    String? error,
    DateTime? lastFetched,
    bool clearError = false,
  }) =>
      ForecastState(
        alerts: alerts ?? this.alerts,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        lastFetched: lastFetched ?? this.lastFetched,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ForecastNotifier extends StateNotifier<ForecastState> {
  final Ref _ref;

  ForecastNotifier(this._ref) : super(const ForecastState()) {
    _fetchForecast();
  }

  Future<void> refresh() => _fetchForecast();

  void dismiss(String alertId) {
    state = state.copyWith(
      alerts: state.alerts
          .map((a) => a.id == alertId ? a.copyWith(dismissed: true) : a)
          .toList(),
    );
  }

  Future<void> _fetchForecast() async {
    state = state.copyWith(loading: true, clearError: true);

    final apiKey = Env.openWeatherApiKey;
    final dashData = await _ref.read(riderDashboardProvider.future);
    final rider = dashData.rider;

    if (apiKey.isEmpty) {
      state = state.copyWith(
        loading: false,
        alerts: _mockAlerts(rider.city),
      );
      return;
    }

    try {
      final lat = rider.location.lat;
      final lng = rider.location.lng;
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast'
        '?lat=$lat&lon=$lng&appid=$apiKey&units=metric&cnt=16',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('OWM error ${response.statusCode}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final list = (body['list'] as List).cast<Map<String, dynamic>>();

      final alerts = <PredictiveAlert>[];
      final now = DateTime.now();

      for (final entry in list) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
            (entry['dt'] as int) * 1000);
        if (dt.isBefore(now)) continue;

        final hoursAhead = dt.difference(now).inHours;
        // Only alert for events 2–30 hours ahead
        if (hoursAhead < 2 || hoursAhead > 30) continue;

        final rain3h =
            (entry['rain']?['3h'] ?? 0.0).toDouble();
        final temp = (entry['main']?['temp'] ?? 0.0).toDouble();

        // Heavy rain
        if (rain3h >= _thresholds['HeavyRain']! * 0.8) {
          final confidence = (rain3h / _thresholds['HeavyRain']!).clamp(0.0, 1.0);
          if (confidence >= 0.8) {
            alerts.add(_makeAlert(
              type: 'HeavyRain',
              dt: dt,
              value: rain3h,
              threshold: _thresholds['HeavyRain']!,
              confidence: confidence,
            ));
          }
        }

        // Extreme heat
        if (temp >= _thresholds['ExtremeHeat']! * 0.85) {
          final confidence = (temp / _thresholds['ExtremeHeat']!).clamp(0.0, 1.0);
          if (confidence >= 0.8) {
            alerts.add(_makeAlert(
              type: 'ExtremeHeat',
              dt: dt,
              value: temp,
              threshold: _thresholds['ExtremeHeat']!,
              confidence: confidence,
            ));
          }
        }

        // Flooding (extreme rain)
        if (rain3h >= _thresholds['Flooding']! * 0.8) {
          alerts.add(_makeAlert(
            type: 'Flooding',
            dt: dt,
            value: rain3h,
            threshold: _thresholds['Flooding']!,
            confidence: 0.9,
          ));
        }
      }

      // De-dup: keep only first occurrence per type in 6h windows
      final seen = <String>{};
      final deduped = alerts.where((a) {
        final key =
            '${a.triggerType}-${a.predictedAt.difference(now).inHours ~/ 6}';
        return seen.add(key);
      }).toList()
        ..sort((a, b) => a.predictedAt.compareTo(b.predictedAt));

      state = state.copyWith(
        loading: false,
        alerts: deduped,
        lastFetched: now,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load forecast: $e',
        alerts: _mockAlerts(rider.city),
      );
    }
  }

  PredictiveAlert _makeAlert({
    required String type,
    required DateTime dt,
    required double value,
    required double threshold,
    required double confidence,
  }) {
    final sev = confidence >= 0.95
        ? AlertSeverity.critical
        : confidence >= 0.88
            ? AlertSeverity.high
            : AlertSeverity.medium;

    final desc = switch (type) {
      'HeavyRain' =>
        'Rainfall of ${value.toStringAsFixed(0)} mm expected — above ${threshold.toStringAsFixed(0)} mm threshold',
      'ExtremeHeat' =>
        'Temperature of ${value.toStringAsFixed(1)}°C expected — above ${threshold.toStringAsFixed(0)}°C threshold',
      'Flooding' =>
        'Extreme rainfall ${value.toStringAsFixed(0)} mm may cause flooding in your zone',
      _ => 'Disruption event predicted',
    };

    return PredictiveAlert(
      id: '${type}_${dt.millisecondsSinceEpoch}',
      triggerType: type,
      description: desc,
      predictedAt: dt,
      alertedAt: DateTime.now(),
      confidence: confidence,
      predictedValue: value,
      threshold: threshold,
      severity: sev,
    );
  }

  List<PredictiveAlert> _mockAlerts(String city) {
    final now = DateTime.now();
    return [
      PredictiveAlert(
        id: 'mock_rain_1',
        triggerType: 'HeavyRain',
        description:
            'Rainfall of 62 mm expected — above 50 mm threshold',
        predictedAt: now.add(const Duration(hours: 5)),
        alertedAt: now,
        confidence: 0.87,
        predictedValue: 62,
        threshold: 50,
        severity: AlertSeverity.high,
      ),
      PredictiveAlert(
        id: 'mock_heat_1',
        triggerType: 'ExtremeHeat',
        description:
            'Temperature of 42.3°C expected — above 40°C threshold',
        predictedAt: now.add(const Duration(hours: 18)),
        alertedAt: now,
        confidence: 0.82,
        predictedValue: 42.3,
        threshold: 40,
        severity: AlertSeverity.medium,
      ),
    ];
  }
}

final forecastProvider =
    StateNotifierProvider<ForecastNotifier, ForecastState>(
        (ref) => ForecastNotifier(ref));
