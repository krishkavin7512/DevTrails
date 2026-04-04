import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(notificationHistoryProvider);
    final notifier = ref.read(notificationHistoryProvider.notifier);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          if (history.any((n) => !n.read))
            TextButton(
              onPressed: () => notifier.markAllRead(),
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: RainCheckTheme.primary, fontSize: 13)),
            ),
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear all',
              onPressed: () => _confirmClear(context, notifier),
            ),
        ],
      ),
      body: history.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _NotificationTile(record: history[i]),
            ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, NotificationHistoryNotifier notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        title: const Text('Clear history?',
            style: TextStyle(color: RainCheckTheme.textPrimary)),
        content: const Text('This removes all notification history.',
            style: TextStyle(color: RainCheckTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: RainCheckTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: RainCheckTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) notifier.clear();
  }
}

// ── Notification tile ─────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationRecord record;
  const _NotificationTile({required this.record});

  static const _typeIcons = <String, IconData>{
    'trigger_alert':    Icons.bolt,
    'claim_approved':   Icons.check_circle_outline,
    'payment_success':  Icons.credit_card,
    'payment_failed':   Icons.warning_amber,
    'welcome':          Icons.waving_hand_outlined,
    'panic_alert':      Icons.sos,
    'predictive_alert': Icons.auto_graph,
  };

  static const _typeColors = <String, Color>{
    'trigger_alert':    RainCheckTheme.warning,
    'claim_approved':   RainCheckTheme.success,
    'payment_success':  RainCheckTheme.primary,
    'payment_failed':   RainCheckTheme.error,
    'welcome':          RainCheckTheme.secondary,
    'panic_alert':      RainCheckTheme.error,
    'predictive_alert': Color(0xFF8B5CF6),
  };

  IconData get _icon =>
      _typeIcons[record.type] ?? Icons.notifications_outlined;
  Color get _color =>
      _typeColors[record.type] ?? RainCheckTheme.textSecondary;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _color.withAlpha(record.read ? 20 : 40),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon,
                  color: _color.withAlpha(record.read ? 120 : 255),
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: TextStyle(
                            color: record.read
                                ? RainCheckTheme.textSecondary
                                : RainCheckTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: record.read
                                ? FontWeight.w400
                                : FontWeight.w600),
                      ),
                    ),
                    if (!record.read)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RainCheckTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    record.body,
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(record.receivedAt),
                    style: const TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                color: RainCheckTheme.textSecondary, size: 52),
            SizedBox(height: 16),
            Text('No notifications yet',
                style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Trigger alerts, claims, and payment\nupdates appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RainCheckTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
}
