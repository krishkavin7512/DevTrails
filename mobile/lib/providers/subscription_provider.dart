import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_response.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────

enum SubscriptionStatus { active, paused, graceperiod, cancelled, none }

class PaymentRecord {
  final String id;
  final int amountPaise;
  final String status; // captured | failed | refunded
  final String type; // onboarding | renewal | payout
  final String? description;
  final String? paymentId;
  final DateTime createdAt;

  const PaymentRecord({
    required this.id,
    required this.amountPaise,
    required this.status,
    required this.type,
    this.description,
    this.paymentId,
    required this.createdAt,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
        id: j['_id'] ?? j['id'] ?? '',
        amountPaise: (j['amountPaise'] ?? j['amount'] ?? 0) as int,
        status: j['status'] ?? 'unknown',
        type: j['type'] ?? 'renewal',
        description: j['description'] as String?,
        paymentId: j['razorpayPaymentId'] as String?,
        createdAt:
            DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );

  String get amountFormatted =>
      '₹${(amountPaise / 100).toStringAsFixed(0)}';

  bool get isSuccess => status == 'captured' || status == 'paid';
}

class SubscriptionInfo {
  final String? subscriptionId;
  final SubscriptionStatus status;
  final DateTime? nextChargeAt;
  final DateTime? graceEndsAt;
  final int weeklyPremiumPaise;
  final String planType;
  final int totalRenewals;

  const SubscriptionInfo({
    this.subscriptionId,
    required this.status,
    this.nextChargeAt,
    this.graceEndsAt,
    required this.weeklyPremiumPaise,
    required this.planType,
    required this.totalRenewals,
  });

  factory SubscriptionInfo.none() => const SubscriptionInfo(
        status: SubscriptionStatus.none,
        weeklyPremiumPaise: 0,
        planType: '',
        totalRenewals: 0,
      );

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) {
    final rawStatus = j['status'] as String? ?? 'none';
    final status = switch (rawStatus) {
      'active' || 'authenticated' => SubscriptionStatus.active,
      'paused' => SubscriptionStatus.paused,
      'grace_period' || 'halted' => SubscriptionStatus.graceperiod,
      'cancelled' || 'completed' => SubscriptionStatus.cancelled,
      _ => SubscriptionStatus.none,
    };
    return SubscriptionInfo(
      subscriptionId: j['subscriptionId'] as String?,
      status: status,
      nextChargeAt:
          DateTime.tryParse(j['nextChargeAt'] ?? j['current_end'] ?? ''),
      graceEndsAt: DateTime.tryParse(j['graceEndsAt'] ?? ''),
      weeklyPremiumPaise:
          (j['weeklyPremiumPaise'] ?? j['amount'] ?? 0) as int,
      planType: j['planType'] ?? '',
      totalRenewals: (j['totalRenewals'] ?? j['paid_count'] ?? 0) as int,
    );
  }

  String get statusLabel => switch (status) {
        SubscriptionStatus.active => 'Active',
        SubscriptionStatus.paused => 'Paused',
        SubscriptionStatus.graceperiod => 'Grace Period',
        SubscriptionStatus.cancelled => 'Cancelled',
        SubscriptionStatus.none => 'No subscription',
      };

  bool get isActive => status == SubscriptionStatus.active;
  bool get inGrace => status == SubscriptionStatus.graceperiod;
}

// ── State ─────────────────────────────────────────────────────────────────

class SubscriptionState {
  final SubscriptionInfo subscription;
  final List<PaymentRecord> history;
  final bool loadingSubscription;
  final bool loadingHistory;
  final bool actioning; // pause/resume/cancel in progress
  final String? error;
  final String? successMessage;

  const SubscriptionState({
    this.subscription = const SubscriptionInfo(
        status: SubscriptionStatus.none,
        weeklyPremiumPaise: 0,
        planType: '',
        totalRenewals: 0),
    this.history = const [],
    this.loadingSubscription = false,
    this.loadingHistory = false,
    this.actioning = false,
    this.error,
    this.successMessage,
  });

  SubscriptionState copyWith({
    SubscriptionInfo? subscription,
    List<PaymentRecord>? history,
    bool? loadingSubscription,
    bool? loadingHistory,
    bool? actioning,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) =>
      SubscriptionState(
        subscription: subscription ?? this.subscription,
        history: history ?? this.history,
        loadingSubscription:
            loadingSubscription ?? this.loadingSubscription,
        loadingHistory: loadingHistory ?? this.loadingHistory,
        actioning: actioning ?? this.actioning,
        error: clearError ? null : (error ?? this.error),
        successMessage:
            clearSuccess ? null : (successMessage ?? this.successMessage),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionNotifier(this._ref) : super(const SubscriptionState()) {
    _load();
  }

  Future<void> _load() async {
    final riderId = _ref.read(authProvider).riderId;
    if (riderId == null) return;
    await Future.wait([
      _loadSubscription(riderId),
      _loadHistory(riderId),
    ]);
  }

  Future<void> refresh() => _load();

  Future<void> _loadSubscription(String riderId) async {
    state = state.copyWith(loadingSubscription: true, clearError: true);
    final res = await ApiService().getSubscriptionStatus(riderId);
    if (res.success && res.data != null) {
      state = state.copyWith(
        loadingSubscription: false,
        subscription: SubscriptionInfo.fromJson(res.data!),
      );
    } else {
      state = state.copyWith(
          loadingSubscription: false,
          subscription: SubscriptionInfo.none());
    }
  }

  Future<void> _loadHistory(String riderId) async {
    state = state.copyWith(loadingHistory: true);
    final res = await ApiService().getPaymentHistory(riderId);
    final records = (res.data ?? [])
        .map((m) => PaymentRecord.fromJson(m))
        .toList();
    state = state.copyWith(loadingHistory: false, history: records);
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> pause() => _action(
        label: 'pause',
        call: () => ApiService()
            .pauseSubscription(state.subscription.subscriptionId!),
        success: 'Subscription paused. Coverage continues until period end.',
      );

  Future<void> resume() => _action(
        label: 'resume',
        call: () => ApiService()
            .resumeSubscription(state.subscription.subscriptionId!),
        success: 'Subscription resumed. Next charge on next billing date.',
      );

  Future<void> cancel() => _action(
        label: 'cancel',
        call: () => ApiService()
            .cancelSubscription(state.subscription.subscriptionId!),
        success: 'Subscription cancelled. Policy active until period end.',
      );

  Future<void> _action({
    required String label,
    required Future<ApiResponse<Map<String, dynamic>>> Function() call,
    required String success,
  }) async {
    if (state.subscription.subscriptionId == null) return;
    state = state.copyWith(
        actioning: true, clearError: true, clearSuccess: true);
    final res = await call();
    if (res.success) {
      state = state.copyWith(actioning: false, successMessage: success);
      _load();
    } else {
      state = state.copyWith(
          actioning: false,
          error: res.error ?? 'Failed to $label subscription');
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>(
        (ref) => SubscriptionNotifier(ref));
