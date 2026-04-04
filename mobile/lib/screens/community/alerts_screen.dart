import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/alert.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import 'report_alert_sheet.dart';
import 'trust_score_screen.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityProvider.notifier).loadNearbyAlerts();
      ref.read(communityProvider.notifier).flushOfflineQueue();
    });
  }

  void _openSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ReportAlertSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(communityProvider);
    final myId = ref.watch(authProvider).riderId ?? '';

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        backgroundColor: RainCheckTheme.background,
        title: const Text('Community Alerts'),
        actions: [
          if (st.trustProfile != null)
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TrustScoreScreen())),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: RainCheckTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: RainCheckTheme.primary.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 14, color: RainCheckTheme.primary),
                    const SizedBox(width: 4),
                    Text('${st.trustProfile!.trustScore}',
                        style: const TextStyle(
                            color: RainCheckTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh,
                color: RainCheckTheme.textSecondary),
            onPressed: () =>
                ref.read(communityProvider.notifier).loadNearbyAlerts(),
          ),
        ],
      ),
      body: st.loadingAlerts
          ? const Center(
              child: CircularProgressIndicator(
                  color: RainCheckTheme.primary))
          : st.nearbyAlerts.isEmpty
              ? _EmptyState(onReport: _openSheet)
              : RefreshIndicator(
                  color: RainCheckTheme.primary,
                  backgroundColor: RainCheckTheme.surface,
                  onRefresh: () => ref
                      .read(communityProvider.notifier)
                      .loadNearbyAlerts(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: st.nearbyAlerts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _AlertCard(
                      alert: st.nearbyAlerts[i],
                      myRiderId: myId,
                      onConfirm: () => ref
                          .read(communityProvider.notifier)
                          .confirmAlert(st.nearbyAlerts[i].id),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSheet,
        backgroundColor: RainCheckTheme.primary,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Report',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Alert card ────────────────────────────────────────────────────────────

class _AlertCard extends StatefulWidget {
  final Alert alert;
  final String myRiderId;
  final Future<bool> Function() onConfirm;
  const _AlertCard(
      {required this.alert,
      required this.myRiderId,
      required this.onConfirm});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _confirming = false;
  bool _confirmed = false;

  static const _typeColors = {
    'Flooding': Color(0xFF3B82F6),
    'RoadClosure': Color(0xFFEF4444),
    'Accident': Color(0xFFF59E0B),
    'HeavyRain': Color(0xFF0891B2),
    'Strike': Color(0xFF8B5CF6),
    'Other': Color(0xFF6B7280),
  };
  static const _typeIcons = {
    'Flooding': Icons.flood,
    'RoadClosure': Icons.block,
    'Accident': Icons.car_crash,
    'HeavyRain': Icons.water_drop,
    'Strike': Icons.groups,
    'Other': Icons.warning_amber,
  };

  Color get _color =>
      _typeColors[widget.alert.type] ?? const Color(0xFF6B7280);
  IconData get _icon =>
      _typeIcons[widget.alert.type] ?? Icons.warning_amber;
  bool get _isOwn => widget.alert.riderId == widget.myRiderId;

  Future<void> _handleConfirm() async {
    setState(() => _confirming = true);
    final ok = await widget.onConfirm();
    if (mounted) {
      setState(() {
        _confirming = false;
        if (ok) _confirmed = true;
      });
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alert;
    final needsConfirmation = !a.verified && a.confirmations < 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(a.type,
                          style: const TextStyle(
                              color: RainCheckTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      if (a.verified)
                        const Icon(Icons.verified,
                            color: RainCheckTheme.success, size: 14),
                    ]),
                    if (a.description.isNotEmpty)
                      Text(a.description,
                          style: const TextStyle(
                              color: RainCheckTheme.textSecondary,
                              fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (_isOwn)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: RainCheckTheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Mine',
                      style: TextStyle(
                          color: RainCheckTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),
            _ConfirmBar(count: a.confirmations, verified: a.verified),
            const SizedBox(height: 10),
            Row(children: [
              Text(_timeAgo(a.createdAt),
                  style: const TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 11)),
              if (a.expiresAt != null) ...[
                const Text(' · ',
                    style: TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 11)),
                Text(
                  'Expires ${_timeAgo(a.expiresAt!)}',
                  style: TextStyle(
                      color: a.isExpired
                          ? RainCheckTheme.error
                          : RainCheckTheme.textSecondary,
                      fontSize: 11),
                ),
              ],
              const Spacer(),
              if (!_isOwn && needsConfirmation && !_confirmed)
                SizedBox(
                  height: 30,
                  child: TextButton.icon(
                    onPressed: _confirming ? null : _handleConfirm,
                    style: TextButton.styleFrom(
                      backgroundColor:
                          RainCheckTheme.primary.withAlpha(20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: _confirming
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RainCheckTheme.primary))
                        : const Icon(Icons.thumb_up_outlined,
                            size: 13,
                            color: RainCheckTheme.primary),
                    label: Text(_confirming ? '…' : 'I see this too',
                        style: const TextStyle(
                            color: RainCheckTheme.primary,
                            fontSize: 12)),
                  ),
                ),
              if (_confirmed)
                const Row(children: [
                  Icon(Icons.check_circle,
                      color: RainCheckTheme.success, size: 14),
                  SizedBox(width: 4),
                  Text('Confirmed',
                      style: TextStyle(
                          color: RainCheckTheme.success,
                          fontSize: 12)),
                ]),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Confirmation progress bar ─────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final int count;
  final bool verified;
  const _ConfirmBar({required this.count, required this.verified});

  @override
  Widget build(BuildContext context) {
    final progress = (count / 3).clamp(0.0, 1.0);
    final color = verified
        ? RainCheckTheme.success
        : count >= 2
            ? RainCheckTheme.warning
            : RainCheckTheme.textSecondary;

    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: verified ? 1.0 : progress,
            backgroundColor: RainCheckTheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        verified ? 'Verified' : '$count/3 confirmations',
        style: TextStyle(color: color, fontSize: 11),
      ),
    ]);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onReport;
  const _EmptyState({required this.onReport});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off,
                color: RainCheckTheme.textSecondary, size: 52),
            const SizedBox(height: 16),
            const Text('No alerts nearby',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Be the first to report a hazard in your area.',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: RainCheckTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text('Report Hazard',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
}
