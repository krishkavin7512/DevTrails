import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// ── Notification history provider ─────────────────────────────────────────

class NotificationHistoryNotifier
    extends StateNotifier<List<NotificationRecord>> {
  NotificationHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final history = await NotificationService().getHistory();
    state = history;
  }

  Future<void> refresh() => _load();

  Future<void> markAllRead() async {
    await NotificationService().markAllRead();
    state = state.map((n) => n.copyWithRead()).toList();
  }

  Future<void> clear() async {
    await NotificationService().clearHistory();
    state = [];
  }

  int get unreadCount => state.where((n) => !n.read).length;
}

final notificationHistoryProvider = StateNotifierProvider<
    NotificationHistoryNotifier, List<NotificationRecord>>(
  (_) => NotificationHistoryNotifier(),
);

final unreadCountProvider = Provider<int>((ref) {
  final history = ref.watch(notificationHistoryProvider);
  return history.where((n) => !n.read).length;
});

// ── Notification prefs provider ───────────────────────────────────────────

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  final Ref _ref;

  NotificationPrefsNotifier(this._ref) : super(const NotificationPrefs()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await NotificationService().getPrefs();
    state = prefs;
  }

  Future<void> update(NotificationPrefs prefs) async {
    state = prefs;
    await NotificationService().savePrefs(prefs);
    // Sync to backend so server-side push filters work
    final riderId = _ref.read(authProvider).riderId;
    if (riderId != null) {
      ApiService().updateNotificationPrefs(riderId, prefs.toJson());
    }
  }

  void toggle(NotificationPrefs Function(NotificationPrefs) updater) {
    update(updater(state));
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
        (ref) => NotificationPrefsNotifier(ref));
