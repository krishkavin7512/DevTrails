import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../models/policy.dart';
import '../../providers/rider_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';

class PolicyManagementScreen extends ConsumerWidget {
  const PolicyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(riderDashboardProvider);
    final subState  = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(title: const Text('My Policy')),
      body: dashAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: RainCheckTheme.primary)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: RainCheckTheme.error))),
        data: (data) {
          final policy = data.policy;
          return RefreshIndicator(
            color: RainCheckTheme.primary,
            onRefresh: () async {
              ref.invalidate(riderDashboardProvider);
              ref.read(subscriptionProvider.notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (policy == null)
                  const _NoPolicyCard()
                else ...[
                  _ActivePolicyCard(policy: policy),
                  const SizedBox(height: 16),
                  _SubscriptionActions(sub: subState, policy: policy),
                  const SizedBox(height: 16),
                  _UpgradeSection(current: policy.planType),
                  const SizedBox(height: 16),
                ],
                _PolicyHistorySection(riderId: data.rider.id),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Active policy card ────────────────────────────────────────────────────────

class _ActivePolicyCard extends StatelessWidget {
  final Policy policy;
  const _ActivePolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    final daysLeft = policy.daysRemaining;
    final urgentColor = daysLeft <= 3
        ? RainCheckTheme.error
        : daysLeft <= 7
            ? RainCheckTheme.warning
            : RainCheckTheme.success;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            RainCheckTheme.primary.withAlpha(40),
            RainCheckTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RainCheckTheme.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield,
                  color: RainCheckTheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${policy.planType} Plan',
                  style: const TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: policy.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(policy.policyNumber,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(
                  label: 'Weekly Premium',
                  value: policy.weeklyPremiumFormatted),
              _Metric(
                  label: 'Coverage Limit',
                  value: policy.coverageLimitFormatted),
              _Metric(
                  label: 'Days Left',
                  value: '$daysLeft',
                  valueColor: urgentColor),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: RainCheckTheme.surfaceVariant, height: 1),
          const SizedBox(height: 14),
          const Text('Covered Disruptions',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: policy.coveredDisruptions
                .map((d) => _DisruptionChip(name: d))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('From ${_fmtDate(policy.startDate)}',
                  style: const TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 12)),
              Text('To ${_fmtDate(policy.endDate)}',
                  style: TextStyle(color: urgentColor, fontSize: 12)),
            ],
          ),
          if (policy.autoRenew) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.autorenew,
                    size: 13, color: RainCheckTheme.success),
                const SizedBox(width: 4),
                Text(
                  'Auto-renews on ${_fmtDate(policy.endDate)}',
                  style: const TextStyle(
                      color: RainCheckTheme.success, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Metric(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: valueColor ?? RainCheckTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 10)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Active'    => RainCheckTheme.success,
      'Expired'   => RainCheckTheme.error,
      'Cancelled' => RainCheckTheme.error,
      _           => RainCheckTheme.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _DisruptionChip extends StatelessWidget {
  final String name;
  const _DisruptionChip({required this.name});

  static const _icons = {
    'HeavyRain':        Icons.water_drop,
    'ExtremeHeat':      Icons.thermostat,
    'SevereAQI':        Icons.air,
    'Flooding':         Icons.flood,
    'SocialDisruption': Icons.warning_amber,
  };
  static const _labels = {
    'HeavyRain':        'Heavy Rain',
    'ExtremeHeat':      'Extreme Heat',
    'SevereAQI':        'Severe AQI',
    'Flooding':         'Flooding',
    'SocialDisruption': 'Disruption',
  };

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: RainCheckTheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: RainCheckTheme.primary.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[name] ?? Icons.shield,
                size: 12, color: RainCheckTheme.primary),
            const SizedBox(width: 4),
            Text(_labels[name] ?? name,
                style: const TextStyle(
                    color: RainCheckTheme.primary, fontSize: 11)),
          ],
        ),
      );
}

// ── Subscription actions ──────────────────────────────────────────────────────

class _SubscriptionActions extends ConsumerWidget {
  final SubscriptionState sub;
  final Policy policy;
  const _SubscriptionActions(
      {required this.sub, required this.policy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info    = sub.subscription;
    final loading = sub.actioning;

    return _SectionCard(
      title: 'Subscription',
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_outlined,
                  color: RainCheckTheme.textSecondary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.statusLabel,
                        style: const TextStyle(
                            color: RainCheckTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                    if (info.nextChargeAt != null)
                      Text(
                        'Next charge: ${_fmtDate(info.nextChargeAt!)}',
                        style: const TextStyle(
                            color: RainCheckTheme.textSecondary,
                            fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (info.totalRenewals > 0)
                Text('${info.totalRenewals} renewals',
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 12)),
            ],
          ),
          if (sub.error != null) ...[
            const SizedBox(height: 8),
            Text(sub.error!,
                style: const TextStyle(
                    color: RainCheckTheme.error, fontSize: 12)),
          ],
          if (sub.successMessage != null) ...[
            const SizedBox(height: 8),
            Text(sub.successMessage!,
                style: const TextStyle(
                    color: RainCheckTheme.success, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          const Divider(color: RainCheckTheme.surfaceVariant, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              if (info.isActive) ...[
                Expanded(
                  child: _ActionBtn(
                    label: 'Pause',
                    icon: Icons.pause_circle_outline,
                    color: RainCheckTheme.warning,
                    loading: loading,
                    onTap: () =>
                        ref.read(subscriptionProvider.notifier).pause(),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (info.status == SubscriptionStatus.paused)
                Expanded(
                  child: _ActionBtn(
                    label: 'Resume',
                    icon: Icons.play_circle_outline,
                    color: RainCheckTheme.success,
                    loading: loading,
                    onTap: () =>
                        ref.read(subscriptionProvider.notifier).resume(),
                  ),
                ),
              if (info.status != SubscriptionStatus.cancelled &&
                  info.status != SubscriptionStatus.none)
                Expanded(
                  child: _ActionBtn(
                    label: 'Cancel',
                    icon: Icons.cancel_outlined,
                    color: RainCheckTheme.error,
                    loading: loading,
                    onTap: () => _confirmCancel(context, ref),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    final refundDays   = policy.daysRemaining;
    final refundAmount =
        (policy.weeklyPremium / 7 * refundDays / 100)
            .toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Subscription?',
            style: TextStyle(color: RainCheckTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your coverage continues until the end of the current period.',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: RainCheckTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Est. pro-rata refund: ₹$refundAmount for $refundDays remaining days.',
                    style: const TextStyle(
                        color: RainCheckTheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Plan',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(subscriptionProvider.notifier).cancel();
            },
            child: const Text('Cancel Subscription',
                style: TextStyle(color: RainCheckTheme.error)),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.loading,
      required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withAlpha(100)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
}

// ── Upgrade section ───────────────────────────────────────────────────────────

class _UpgradeSection extends StatelessWidget {
  final String current;
  const _UpgradeSection({required this.current});

  static const _plans = [
    _PlanDef('Basic', 'HeavyRain only', 4900, 50000,
        Color(0xFF6B7280)),
    _PlanDef('Standard', 'Rain + Heat + AQI', 9900, 100000,
        RainCheckTheme.primary),
    _PlanDef('Premium', 'All 5 disruptions', 14900, 150000,
        RainCheckTheme.warning),
  ];

  @override
  Widget build(BuildContext context) {
    final order       = ['Basic', 'Standard', 'Premium'];
    final currentIdx  = order.indexOf(current);
    final upgradable  = _plans
        .where((p) => order.indexOf(p.name) > currentIdx)
        .toList();

    if (upgradable.isEmpty) {
      return const _SectionCard(
        title: 'Plan',
        child: Row(
          children: [
            Icon(Icons.workspace_premium,
                color: RainCheckTheme.warning, size: 20),
            SizedBox(width: 10),
            Text('You are on the highest plan!',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'Upgrade Plan',
      child: Column(
        children: upgradable
            .map((p) => _PlanTile(
                plan: p, isCurrent: p.name == current))
            .toList(),
      ),
    );
  }
}

class _PlanDef {
  final String name;
  final String tagline;
  final int weeklyPaise;
  final int coveragePaise;
  final Color color;
  const _PlanDef(this.name, this.tagline, this.weeklyPaise,
      this.coveragePaise, this.color);
}

class _PlanTile extends StatelessWidget {
  final _PlanDef plan;
  final bool isCurrent;
  const _PlanTile({required this.plan, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: plan.color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isCurrent
                ? plan.color
                : plan.color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name,
                        style: TextStyle(
                            color: plan.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: plan.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Current',
                            style: TextStyle(
                                color: plan.color, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(plan.tagline,
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '₹${plan.weeklyPaise ~/ 100}/wk  ·  Coverage ₹${plan.coveragePaise ~/ 100}',
                  style: const TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            ElevatedButton(
              onPressed: () => _showDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: plan.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Upgrade to ${plan.name}?',
            style: const TextStyle(
                color: RainCheckTheme.textPrimary)),
        content: Text(
          'Your new weekly premium will be ₹${plan.weeklyPaise ~/ 100} with coverage up to ₹${plan.coveragePaise ~/ 100}.\n\nThe change takes effect on your next billing date.',
          style: const TextStyle(
              color: RainCheckTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Toast.success(context, 'Upgrade to ${plan.name} requested');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: plan.color,
                foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ── Policy history ────────────────────────────────────────────────────────────

class _PolicyHistorySection extends StatefulWidget {
  final String riderId;
  const _PolicyHistorySection({required this.riderId});

  @override
  State<_PolicyHistorySection> createState() =>
      _PolicyHistorySectionState();
}

class _PolicyHistorySectionState
    extends State<_PolicyHistorySection> {
  List<Policy>? _policies;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService().getRiderPolicies(widget.riderId);
    if (mounted) {
      setState(() {
        _policies = res.data ?? [];
        _loading  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Policy History',
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: RainCheckTheme.primary, strokeWidth: 2))
          : (_policies == null || _policies!.isEmpty)
              ? const Text('No past policies.',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 13))
              : Column(
                  children: _policies!
                      .map((p) => _HistoryRow(policy: p))
                      .toList(),
                ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Policy policy;
  const _HistoryRow({required this.policy});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(policy.policyNumber,
                      style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(
                    '${policy.planType} · ${policy.weeklyPremiumFormatted}/wk',
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 12),
                  ),
                  Text(
                    '${_fmt(policy.startDate)} – ${_fmt(policy.endDate)}',
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            _StatusChip(status: policy.status),
          ],
        ),
      );

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _NoPolicyCard extends StatelessWidget {
  const _NoPolicyCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: RainCheckTheme.surfaceVariant),
        ),
        child: const Column(
          children: [
            Icon(Icons.shield_outlined,
                color: RainCheckTheme.textSecondary, size: 48),
            SizedBox(height: 12),
            Text('No Active Policy',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Subscribe to a plan to get coverage.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 13)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: RainCheckTheme.surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}
