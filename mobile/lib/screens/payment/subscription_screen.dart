import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../providers/subscription_provider.dart';
import 'payment_history_screen.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(subscriptionProvider);

    // Show snackbar on success/error
    ref.listen(subscriptionProvider, (prev, next) {
      if (next.successMessage != null &&
          prev?.successMessage != next.successMessage) {
        Toast.success(context, next.successMessage!);
      }
      if (next.error != null && prev?.error != next.error) {
        Toast.error(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Payment History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(subscriptionProvider.notifier).refresh(),
          ),
        ],
      ),
      body: st.loadingSubscription
          ? const Center(
              child: CircularProgressIndicator(color: RainCheckTheme.primary),
            )
          : RefreshIndicator(
              color: RainCheckTheme.primary,
              backgroundColor: RainCheckTheme.surface,
              onRefresh: () =>
                  ref.read(subscriptionProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusCard(sub: st.subscription),
                    const SizedBox(height: 16),
                    if (st.subscription.status != SubscriptionStatus.none) ...[
                      _BillingInfo(sub: st.subscription),
                      const SizedBox(height: 16),
                      _ActionButtons(
                        sub: st.subscription,
                        actioning: st.actioning,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _RecentPayments(
                      history: st.history.take(3).toList(),
                      loading: st.loadingHistory,
                    ),
                    const SizedBox(height: 8),
                    if (st.history.isNotEmpty)
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaymentHistoryScreen(),
                            ),
                          ),
                          child: const Text(
                            'View all payments',
                            style: TextStyle(color: RainCheckTheme.primary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final SubscriptionInfo sub;
  const _StatusCard({required this.sub});

  Color get _color => switch (sub.status) {
    SubscriptionStatus.active => RainCheckTheme.success,
    SubscriptionStatus.paused => RainCheckTheme.warning,
    SubscriptionStatus.graceperiod => RainCheckTheme.error,
    SubscriptionStatus.cancelled => RainCheckTheme.textSecondary,
    SubscriptionStatus.none => RainCheckTheme.textSecondary,
  };

  IconData get _icon => switch (sub.status) {
    SubscriptionStatus.active => Icons.check_circle,
    SubscriptionStatus.paused => Icons.pause_circle,
    SubscriptionStatus.graceperiod => Icons.warning_amber,
    SubscriptionStatus.cancelled => Icons.cancel_outlined,
    SubscriptionStatus.none => Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: _color, size: 24),
                const SizedBox(width: 10),
                Text(
                  sub.statusLabel,
                  style: TextStyle(
                    color: _color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (sub.planType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: RainCheckTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sub.planType,
                      style: const TextStyle(
                        color: RainCheckTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (sub.status == SubscriptionStatus.graceperiod) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RainCheckTheme.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: RainCheckTheme.error.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      color: RainCheckTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sub.graceEndsAt != null
                            ? 'Grace period ends ${_fmtDate(sub.graceEndsAt!)}. Update payment to keep coverage.'
                            : 'Payment failed. Update payment method to keep coverage.',
                        style: const TextStyle(
                          color: RainCheckTheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (sub.weeklyPremiumPaise > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      label: 'Weekly Premium',
                      value:
                          '₹${(sub.weeklyPremiumPaise / 100).toStringAsFixed(0)}',
                    ),
                  ),
                  Expanded(
                    child: _InfoTile(
                      label: 'Renewals',
                      value: '${sub.totalRenewals}×',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: RainCheckTheme.textSecondary,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: RainCheckTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

// ── Billing info ──────────────────────────────────────────────────────────

class _BillingInfo extends StatelessWidget {
  final SubscriptionInfo sub;
  const _BillingInfo({required this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (sub.nextChargeAt != null)
              _BillingRow(
                icon: Icons.calendar_today,
                label: sub.status == SubscriptionStatus.paused
                    ? 'Billing paused'
                    : 'Next charge',
                value: _fmtDate(sub.nextChargeAt!),
              ),
            const SizedBox(height: 8),
            const _BillingRow(
              icon: Icons.repeat,
              label: 'Billing cycle',
              value: 'Weekly (auto-renew)',
            ),
            const SizedBox(height: 8),
            const _BillingRow(
              icon: Icons.account_balance,
              label: 'Payment method',
              value: 'UPI / Card via Razorpay',
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

class _BillingRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _BillingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: RainCheckTheme.textSecondary, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: RainCheckTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: RainCheckTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

// ── Action buttons ────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final SubscriptionInfo sub;
  final bool actioning;
  const _ActionButtons({required this.sub, required this.actioning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sub.status == SubscriptionStatus.cancelled ||
        sub.status == SubscriptionStatus.none) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (sub.status == SubscriptionStatus.active) ...[
              _ActionTile(
                icon: Icons.pause_circle_outline,
                label: 'Pause subscription',
                subtitle: 'Coverage continues until end of current week',
                color: RainCheckTheme.warning,
                loading: actioning,
                onTap: () => _confirm(
                  context,
                  ref,
                  'Pause subscription?',
                  'Billing will pause after this week. Coverage remains active until period end.',
                  ref.read(subscriptionProvider.notifier).pause,
                ),
              ),
            ],
            if (sub.status == SubscriptionStatus.paused) ...[
              _ActionTile(
                icon: Icons.play_circle_outline,
                label: 'Resume subscription',
                subtitle: 'Billing resumes on next cycle',
                color: RainCheckTheme.success,
                loading: actioning,
                onTap: () => ref.read(subscriptionProvider.notifier).resume(),
              ),
            ],
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.cancel_outlined,
              label: 'Cancel subscription',
              subtitle: 'Cancels at end of current week',
              color: RainCheckTheme.error,
              loading: false,
              onTap: () => _confirm(
                context,
                ref,
                'Cancel subscription?',
                'Your policy will remain active until the end of this week, then coverage ends.',
                ref.read(subscriptionProvider.notifier).cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    String title,
    String body,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        title: Text(
          title,
          style: const TextStyle(color: RainCheckTheme.textPrimary),
        ),
        content: Text(
          body,
          style: const TextStyle(color: RainCheckTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Back',
              style: TextStyle(color: RainCheckTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: RainCheckTheme.error,
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await action();
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: loading ? null : onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: RainCheckTheme.primary,
              ),
            )
          else
            const Icon(
              Icons.chevron_right,
              color: RainCheckTheme.textSecondary,
            ),
        ],
      ),
    ),
  );
}

// ── Recent payments preview ───────────────────────────────────────────────

class _RecentPayments extends StatelessWidget {
  final List<PaymentRecord> history;
  final bool loading;
  const _RecentPayments({required this.history, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(
              color: RainCheckTheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (history.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Payments',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...history.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            (r.isSuccess
                                    ? RainCheckTheme.success
                                    : RainCheckTheme.error)
                                .withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        r.type == 'payout'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.autorenew,
                        color: r.isSuccess
                            ? RainCheckTheme.success
                            : RainCheckTheme.error,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.description ??
                            '${r.type[0].toUpperCase()}${r.type.substring(1)}',
                        style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '${r.type == 'payout' ? '+' : '−'}${r.amountFormatted}',
                      style: TextStyle(
                        color: r.isSuccess
                            ? (r.type == 'payout'
                                  ? RainCheckTheme.success
                                  : RainCheckTheme.primary)
                            : RainCheckTheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
