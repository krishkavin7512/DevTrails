import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/subscription_provider.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(subscriptionProvider.notifier).refresh(),
          ),
        ],
      ),
      body: st.loadingHistory
          ? const Center(
              child: CircularProgressIndicator(
                  color: RainCheckTheme.primary))
          : st.history.isEmpty
              ? _EmptyHistory()
              : RefreshIndicator(
                  color: RainCheckTheme.primary,
                  backgroundColor: RainCheckTheme.surface,
                  onRefresh: () =>
                      ref.read(subscriptionProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: st.history.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _PaymentTile(record: st.history[i]),
                  ),
                ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                color: RainCheckTheme.textSecondary, size: 52),
            SizedBox(height: 16),
            Text('No payment records yet',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Your premiums and payouts will appear here.',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 14)),
          ],
        ),
      );
}

class _PaymentTile extends StatelessWidget {
  final PaymentRecord record;
  const _PaymentTile({required this.record});

  static const _typeIcons = {
    'onboarding': Icons.shield_outlined,
    'renewal': Icons.autorenew,
    'payout': Icons.account_balance_wallet_outlined,
    'refund': Icons.undo,
  };

  static const _typeLabels = {
    'onboarding': 'Initial Premium',
    'renewal': 'Weekly Renewal',
    'payout': 'Claim Payout',
    'refund': 'Refund',
  };

  @override
  Widget build(BuildContext context) {
    final isPayout = record.type == 'payout' || record.type == 'refund';
    final color = record.isSuccess
        ? (isPayout ? RainCheckTheme.success : RainCheckTheme.primary)
        : RainCheckTheme.error;
    final icon =
        _typeIcons[record.type] ?? Icons.payment;
    final label =
        _typeLabels[record.type] ?? record.type;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    record.description ??
                        _formatDate(record.createdAt),
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 12),
                  ),
                  if (record.paymentId != null)
                    Text(
                      record.paymentId!,
                      style: const TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 10),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPayout ? '+' : '−'}${record.amountFormatted}',
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _StatusChip(
                    status: record.status, isSuccess: record.isSuccess),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isSuccess;
  const _StatusChip({required this.status, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color =
        isSuccess ? RainCheckTheme.success : RainCheckTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}
