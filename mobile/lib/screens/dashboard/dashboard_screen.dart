import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/claim.dart';
import '../../models/policy.dart';
import '../../models/rider.dart';
import '../../providers/rider_provider.dart';
import '../../widgets/error_widgets.dart';
import '../../widgets/shimmer_widgets.dart';
import 'widgets/minimap_widget.dart';
import '../community/alerts_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderDashboardProvider);
    return async.when(
      loading: () => const DashboardShimmer(),
      error: (e, _) => NetworkErrorScreen(
        message: e.toString(),
        onRetry: () => ref.invalidate(riderDashboardProvider),
      ),
      data: (data) => _DashboardContent(data: data),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final RiderDashboardData data;
  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: RainCheckTheme.primary,
      backgroundColor: RainCheckTheme.surface,
      onRefresh: () async {
        await Haptics.medium();
        ref.invalidate(riderDashboardProvider);
      },
      child: CustomScrollView(
        slivers: [
          _buildAppBar(data.rider),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _PolicyCard(policy: data.policy),
                const SizedBox(height: 16),
                _WeatherStatusCard(),
                const SizedBox(height: 16),
                const MinimapWidget(),
                const SizedBox(height: 16),
                _RecentClaimsSection(claims: data.recentClaims),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(Rider rider) {
    return SliverAppBar(
      backgroundColor: RainCheckTheme.background,
      pinned: true,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: RainCheckTheme.primary.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop,
                color: RainCheckTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('RainCheck'),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: RainCheckTheme.surfaceVariant,
            child: Text(
              rider.fullName.isNotEmpty
                  ? rider.fullName[0].toUpperCase()
                  : 'R',
              style: const TextStyle(
                  color: RainCheckTheme.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${rider.fullName.split(' ').first}',
                      style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rider.city} · ${rider.operatingZone}',
                      style: const TextStyle(
                          color: RainCheckTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _RiskBadge(tier: rider.riskTier),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String tier;
  const _RiskBadge({required this.tier});
  @override
  Widget build(BuildContext context) {
    final color = tier == 'High'
        ? RainCheckTheme.error
        : tier == 'Medium'
            ? RainCheckTheme.warning
            : RainCheckTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text('$tier Risk',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final Policy? policy;
  const _PolicyCard({required this.policy});

  @override
  Widget build(BuildContext context) {
    if (policy == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.shield_outlined,
                  color: RainCheckTheme.textSecondary, size: 40),
              const SizedBox(height: 12),
              const Text('No Active Policy',
                  style: TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Get covered against weather disruptions',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RainCheckTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('View Plans',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isActive = policy!.status == 'Active';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [const Color(0xFF1D4ED8), const Color(0xFF0891B2)]
              : [RainCheckTheme.surface, RainCheckTheme.surfaceVariant],
        ),
        border: Border.all(
          color: isActive
              ? RainCheckTheme.primary.withAlpha(80)
              : RainCheckTheme.surfaceVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${policy!.planType} Plan',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withAlpha(40)
                        : RainCheckTheme.error.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(policy!.status,
                      style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : RainCheckTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(policy!.policyNumber,
                style: TextStyle(
                    color: Colors.white.withAlpha(160), fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _Stat(
                        label: 'Weekly Premium',
                        value: policy!.weeklyPremiumFormatted)),
                Expanded(
                    child: _Stat(
                        label: 'Max Coverage',
                        value: policy!.coverageLimitFormatted)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: policy!.coveredDisruptions
                  .map((d) => _TriggerChip(label: d))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(160), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _TriggerChip extends StatelessWidget {
  final String label;
  const _TriggerChip({required this.label});
  static const _icons = {
    'HeavyRain': Icons.water_drop,
    'ExtremeHeat': Icons.thermostat,
    'SevereAQI': Icons.air,
    'Flooding': Icons.flood,
    'SocialDisruption': Icons.warning_amber,
  };
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[label] ?? Icons.shield,
                color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
}

class _WeatherStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: RainCheckTheme.success.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wb_sunny_outlined,
                      color: RainCheckTheme.success),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Clear',
                          style: TextStyle(
                              color: RainCheckTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('No active disruptions in your zone',
                          style: TextStyle(
                              color: RainCheckTheme.textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: RainCheckTheme.textSecondary),
              ],
            ),
          ),
        ),
      );
}

class _RecentClaimsSection extends StatelessWidget {
  final List<Claim> claims;
  const _RecentClaimsSection({required this.claims});

  static const _statusColors = {
    'Paid': RainCheckTheme.success,
    'Approved': RainCheckTheme.success,
    'AutoInitiated': RainCheckTheme.warning,
    'UnderReview': RainCheckTheme.warning,
    'Rejected': RainCheckTheme.error,
    'FraudSuspected': RainCheckTheme.error,
  };
  static const _triggerIcons = {
    'HeavyRain': Icons.water_drop,
    'ExtremeHeat': Icons.thermostat,
    'SevereAQI': Icons.air,
    'Flooding': Icons.flood,
    'SocialDisruption': Icons.warning_amber,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Claims',
            style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (claims.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No claims yet',
                      style: TextStyle(
                          color: RainCheckTheme.textSecondary))),
            ),
          )
        else
          ...claims.map((c) {
            final color =
                _statusColors[c.status] ?? RainCheckTheme.textSecondary;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: RainCheckTheme.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          _triggerIcons[c.triggerType] ?? Icons.shield,
                          color: RainCheckTheme.primary,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.triggerType,
                              style: const TextStyle(
                                  color: RainCheckTheme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(c.claimNumber,
                              style: const TextStyle(
                                  color: RainCheckTheme.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(c.payoutFormatted,
                            style: const TextStyle(
                                color: RainCheckTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(c.status,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
