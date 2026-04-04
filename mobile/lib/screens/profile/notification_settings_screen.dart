import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/notification_provider.dart';
import 'notification_history_screen.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Notification history',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationHistoryScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Delivery channels ───────────────────────────────────────
          const _SectionHeader('Delivery Channels'),
          _PrefTile(
            icon: Icons.notifications_active,
            title: 'Push Notifications',
            subtitle: 'Alerts sent to this device',
            value: prefs.pushEnabled,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(pushEnabled: v)),
          ),
          _PrefTile(
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp Notifications',
            subtitle: 'Messages sent to your registered number',
            value: prefs.whatsappEnabled,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(whatsappEnabled: v)),
          ),

          const SizedBox(height: 20),

          // ── Notification types ──────────────────────────────────────
          const _SectionHeader('Notification Types'),
          _PrefTile(
            icon: Icons.bolt,
            title: 'Trigger Alerts',
            subtitle: 'Weather disruption detected in your zone',
            value: prefs.triggerAlerts,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(triggerAlerts: v)),
          ),
          _PrefTile(
            icon: Icons.check_circle_outline,
            title: 'Claim Updates',
            subtitle: 'Claim approved, rejected, or payout sent',
            value: prefs.claimUpdates,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(claimUpdates: v)),
          ),
          _PrefTile(
            icon: Icons.credit_card,
            title: 'Payment Reminders',
            subtitle: 'Premium charged, failed, or grace period',
            value: prefs.paymentReminders,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(paymentReminders: v)),
          ),
          _PrefTile(
            icon: Icons.people_outline,
            title: 'Community Alerts',
            subtitle: 'Hazards reported by nearby riders',
            value: prefs.communityAlerts,
            onChanged: (v) => ref
                .read(notificationPrefsProvider.notifier)
                .toggle((p) => p.copyWith(communityAlerts: v)),
          ),

          const SizedBox(height: 20),

          // ── Always-on (cannot disable) ──────────────────────────────
          const _SectionHeader('Always On'),
          const _LockedTile(
            icon: Icons.sos,
            title: 'Emergency Alerts',
            subtitle: 'Panic alerts from nearby riders cannot be disabled',
          ),

          const SizedBox(height: 20),

          // ── Actions ─────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationHistoryScreen(),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: RainCheckTheme.surfaceVariant),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.history,
              color: RainCheckTheme.textSecondary,
            ),
            label: const Text(
              'View Notification History',
              style: TextStyle(color: RainCheckTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        color: RainCheckTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: SwitchListTile(
      secondary: Icon(
        icon,
        color: value ? RainCheckTheme.primary : RainCheckTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: RainCheckTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: RainCheckTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: RainCheckTheme.primary,
      activeTrackColor: RainCheckTheme.primary.withAlpha(80),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

class _LockedTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _LockedTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: RainCheckTheme.error, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: RainCheckTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: RainCheckTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: RainCheckTheme.success.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Always On',
          style: TextStyle(
            color: RainCheckTheme.success,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
