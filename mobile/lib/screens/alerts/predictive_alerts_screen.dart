import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/forecast_provider.dart';

class PredictiveAlertsScreen extends ConsumerWidget {
  const PredictiveAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(forecastProvider);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Weather Alerts'),
            if (state.activeCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: RainCheckTheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.activeCount}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(forecastProvider.notifier).refresh(),
            tooltip: 'Refresh forecast',
          ),
        ],
      ),
      body: state.loading
          ? const Center(
              child: CircularProgressIndicator(color: RainCheckTheme.primary))
          : RefreshIndicator(
              color: RainCheckTheme.primary,
              onRefresh: () =>
                  ref.read(forecastProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.error != null)
                    _ErrorBanner(message: state.error!),

                  _InfoBanner(lastFetched: state.lastFetched),
                  const SizedBox(height: 16),

                  if (state.alerts.isEmpty) ...[
                    const _EmptyState(),
                  ] else ...[
                    const _SectionLabel('Active Predictions (≥80% confidence)'),
                    const SizedBox(height: 10),
                    ...state.alerts
                        .where((a) => !a.dismissed && a.confidence >= 0.8)
                        .map((a) => _AlertCard(
                              alert: a,
                              onDismiss: () => ref
                                  .read(forecastProvider.notifier)
                                  .dismiss(a.id),
                            )),

                    const SizedBox(height: 20),
                    if (state.alerts
                        .where((a) => a.confidence < 0.8)
                        .isNotEmpty) ...[
                      const _SectionLabel('Lower Confidence (<80%)'),
                      const SizedBox(height: 10),
                      ...state.alerts
                          .where((a) => a.confidence < 0.8)
                          .map((a) => _AlertCard(
                                alert: a,
                                onDismiss: () => ref
                                    .read(forecastProvider.notifier)
                                    .dismiss(a.id),
                                dimmed: true,
                              )),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Alert card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final PredictiveAlert alert;
  final VoidCallback onDismiss;
  final bool dimmed;
  const _AlertCard(
      {required this.alert, required this.onDismiss, this.dimmed = false});

  static const _typeIcons = {
    'HeavyRain':   Icons.water_drop,
    'ExtremeHeat': Icons.thermostat,
    'SevereAQI':   Icons.air,
    'Flooding':    Icons.flood,
  };

  Color get _severityColor {
    if (dimmed) return RainCheckTheme.textSecondary;
    return switch (alert.severity) {
      AlertSeverity.critical => RainCheckTheme.error,
      AlertSeverity.high     => RainCheckTheme.warning,
      AlertSeverity.medium   => RainCheckTheme.primary,
      AlertSeverity.low      => RainCheckTheme.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor;
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: RainCheckTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.check, color: RainCheckTheme.textSecondary),
      ),
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(dimmed ? 30 : 60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _typeIcons[alert.triggerType] ?? Icons.warning,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(alert.triggerType),
                        style: TextStyle(
                            color: dimmed
                                ? RainCheckTheme.textSecondary
                                : RainCheckTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        alert.hoursUntil,
                        style: TextStyle(
                            color: color, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _ConfidenceBadge(
                    confidence: alert.confidence, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.description,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            // Confidence bar
            Row(
              children: [
                const Text('Confidence',
                    style: TextStyle(
                        color: RainCheckTheme.textSecondary, fontSize: 11)),
                const Spacer(),
                Text(alert.confidenceLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: alert.confidence,
                backgroundColor: RainCheckTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: RainCheckTheme.textSecondary),
                SizedBox(width: 4),
                Text(
                  'Your policy will auto-trigger if threshold is crossed',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String t) => const {
        'HeavyRain':   'Heavy Rainfall',
        'ExtremeHeat': 'Extreme Heat',
        'SevereAQI':   'Severe AQI',
        'Flooding':    'Flooding',
      }[t] ??
      t;
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  final Color color;
  const _ConfidenceBadge({required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '${(confidence * 100).toStringAsFixed(0)}%',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Info banner & empty state ─────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final DateTime? lastFetched;
  const _InfoBanner({required this.lastFetched});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RainCheckTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RainCheckTheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: RainCheckTheme.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastFetched != null
                  ? 'Forecast updated ${_ago(lastFetched!)}. Alerts ≥80% confidence will trigger push notifications 6h before.'
                  : 'Fetching 5-day forecast from OpenWeatherMap…',
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RainCheckTheme.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RainCheckTheme.warning.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: RainCheckTheme.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: RainCheckTheme.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            color: RainCheckTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: RainCheckTheme.success.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: RainCheckTheme.success, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('All clear!',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'No weather disruptions predicted\nin the next 30 hours\nfor your operating zone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
