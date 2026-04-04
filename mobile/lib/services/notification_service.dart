import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'storage_service.dart';

// ── Background handler (top-level, required by FCM) ───────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by the OS on Android.
  // No additional work needed here for now.
}

// ── Navigation callback (set by the widget tree after build) ─────────────────

typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

// ── Service ───────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _fcm   = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  NotificationTapCallback? onTap;

  // ── Android notification channels ─────────────────────────────────────────

  static const _channelDefault = AndroidNotificationChannel(
    'raincheck_default',
    'RainCheck Alerts',
    description: 'Trigger alerts, claims, and payment updates',
    importance: Importance.high,
  );

  static const _channelEmergency = AndroidNotificationChannel(
    'raincheck_emergency',
    'Emergency Alerts',
    description: 'Panic and crash alerts from nearby riders',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ── Initialize ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1. Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
    );

    // 2. Create Android channels
    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelDefault);
    await androidPlugin?.createNotificationChannel(_channelEmergency);

    // 3. Init local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // 4. FCM token
    _fcmToken = await _fcm.getToken();
    if (_fcmToken != null) _registerToken(_fcmToken!);

    _fcm.onTokenRefresh.listen(_registerToken);

    // 5. Wire FCM handlers
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onTapped);

    // 6. Check if app was launched from a notification (terminated state)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNavigation(initial.data);
  }

  // ── Token registration ─────────────────────────────────────────────────────

  Future<void> _registerToken(String token) async {
    _fcmToken = token;
    final riderId = await StorageService().getRiderId();
    if (riderId != null) {
      await ApiService().updateFcmToken(riderId, token);
    }
  }

  // ── Foreground handler ─────────────────────────────────────────────────────

  Future<void> _onForeground(RemoteMessage msg) async {
    final n    = msg.notification;
    final type = msg.data['type'] as String? ?? 'default';
    final isEmergency = type == 'panic_alert';

    // Store in history
    await _saveToHistory(msg);

    await _local.show(
      msg.hashCode,
      n?.title ?? 'RainCheck',
      n?.body  ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          isEmergency ? _channelEmergency.id : _channelDefault.id,
          isEmergency ? _channelEmergency.name : _channelDefault.name,
          importance: isEmergency ? Importance.max : Importance.high,
          priority:   isEmergency ? Priority.max  : Priority.high,
          color:      const Color(0xFF3B82F6),
          icon:       '@mipmap/ic_launcher',
          styleInformation: n?.body != null
              ? BigTextStyleInformation(n!.body!)
              : null,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  // ── Notification tapped handlers ───────────────────────────────────────────

  void _onLocalTap(NotificationResponse r) {
    if (r.payload == null) return;
    try {
      final data = jsonDecode(r.payload!) as Map<String, dynamic>;
      _handleNavigation(data);
    } catch (_) {}
  }

  void _onTapped(RemoteMessage msg) {
    _saveToHistory(msg);
    _handleNavigation(msg.data);
  }

  void _handleNavigation(Map<String, dynamic> data) {
    onTap?.call(data);
  }

  // ── History persistence (SharedPreferences) ────────────────────────────────

  static const _historyKey = 'notification_history';
  static const _maxHistory = 50;

  Future<void> _saveToHistory(RemoteMessage msg) async {
    final prefs   = await _getPrefs();
    final raw     = prefs.getStringList(_historyKey) ?? [];
    final entry   = jsonEncode({
      'id':        msg.messageId ?? DateTime.now().toIso8601String(),
      'title':     msg.notification?.title ?? '',
      'body':      msg.notification?.body  ?? '',
      'type':      msg.data['type'] ?? 'default',
      'data':      msg.data,
      'read':      false,
      'receivedAt': DateTime.now().toIso8601String(),
    });
    raw.insert(0, entry);
    if (raw.length > _maxHistory) raw.removeRange(_maxHistory, raw.length);
    await prefs.setStringList(_historyKey, raw);
  }

  Future<List<NotificationRecord>> getHistory() async {
    final prefs = await _getPrefs();
    final raw   = prefs.getStringList(_historyKey) ?? [];
    return raw.map((s) {
      try {
        return NotificationRecord.fromJson(
            jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<NotificationRecord>().toList();
  }

  Future<void> markAllRead() async {
    final prefs = await _getPrefs();
    final raw   = prefs.getStringList(_historyKey) ?? [];
    final updated = raw.map((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        m['read'] = true;
        return jsonEncode(m);
      } catch (_) { return s; }
    }).toList();
    await prefs.setStringList(_historyKey, updated);
  }

  Future<void> clearHistory() async {
    final prefs = await _getPrefs();
    await prefs.remove(_historyKey);
  }

  Future<int> unreadCount() async {
    final history = await getHistory();
    return history.where((n) => !n.read).length;
  }

  // ── Preferences ────────────────────────────────────────────────────────────

  static const _prefsKey = 'notification_prefs';

  Future<NotificationPrefs> getPrefs() async {
    final prefs = await _getPrefs();
    final raw   = prefs.getString(_prefsKey);
    if (raw == null) return const NotificationPrefs();
    try {
      return NotificationPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NotificationPrefs();
    }
  }

  Future<void> savePrefs(NotificationPrefs p) async {
    final prefs = await _getPrefs();
    await prefs.setString(_prefsKey, jsonEncode(p.toJson()));
  }

  // ── Local show (used internally by backend-triggered local alerts) ─────────

  Future<void> showLocal({
    required String title,
    required String body,
    String type = 'default',
    Map<String, dynamic>? data,
  }) async {
    final isEmergency = type == 'panic_alert';
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isEmergency ? _channelEmergency.id : _channelDefault.id,
          isEmergency ? _channelEmergency.name : _channelDefault.name,
          importance: isEmergency ? Importance.max : Importance.high,
          priority:   isEmergency ? Priority.max  : Priority.high,
          color:      const Color(0xFF3B82F6),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'type': type, ...?data}),
    );
  }

  Future<dynamic> _getPrefs() => StorageService().getPrefsInstance();
}

// ── Models ────────────────────────────────────────────────────────────────────

class NotificationRecord {
  final String id;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime receivedAt;

  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.read,
    required this.receivedAt,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> j) =>
      NotificationRecord(
        id:         j['id'] as String? ?? '',
        title:      j['title'] as String? ?? '',
        body:       j['body']  as String? ?? '',
        type:       j['type']  as String? ?? 'default',
        data:       (j['data'] as Map?)?.cast<String, dynamic>() ?? {},
        read:       j['read']  as bool? ?? false,
        receivedAt: DateTime.tryParse(j['receivedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  NotificationRecord copyWithRead() => NotificationRecord(
        id: id, title: title, body: body, type: type,
        data: data, read: true, receivedAt: receivedAt);
}

class NotificationPrefs {
  final bool pushEnabled;
  final bool whatsappEnabled;
  final bool triggerAlerts;
  final bool claimUpdates;
  final bool paymentReminders;
  final bool communityAlerts;
  // Emergency alerts cannot be disabled

  const NotificationPrefs({
    this.pushEnabled       = true,
    this.whatsappEnabled   = true,
    this.triggerAlerts     = true,
    this.claimUpdates      = true,
    this.paymentReminders  = true,
    this.communityAlerts   = true,
  });

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? whatsappEnabled,
    bool? triggerAlerts,
    bool? claimUpdates,
    bool? paymentReminders,
    bool? communityAlerts,
  }) => NotificationPrefs(
    pushEnabled:      pushEnabled      ?? this.pushEnabled,
    whatsappEnabled:  whatsappEnabled  ?? this.whatsappEnabled,
    triggerAlerts:    triggerAlerts    ?? this.triggerAlerts,
    claimUpdates:     claimUpdates     ?? this.claimUpdates,
    paymentReminders: paymentReminders ?? this.paymentReminders,
    communityAlerts:  communityAlerts  ?? this.communityAlerts,
  );

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        pushEnabled:      j['pushEnabled']      as bool? ?? true,
        whatsappEnabled:  j['whatsappEnabled']  as bool? ?? true,
        triggerAlerts:    j['triggerAlerts']    as bool? ?? true,
        claimUpdates:     j['claimUpdates']     as bool? ?? true,
        paymentReminders: j['paymentReminders'] as bool? ?? true,
        communityAlerts:  j['communityAlerts']  as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'pushEnabled':      pushEnabled,
    'whatsappEnabled':  whatsappEnabled,
    'triggerAlerts':    triggerAlerts,
    'claimUpdates':     claimUpdates,
    'paymentReminders': paymentReminders,
    'communityAlerts':  communityAlerts,
  };
}
