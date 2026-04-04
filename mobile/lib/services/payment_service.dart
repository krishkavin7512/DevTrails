import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/environment.dart';
import 'api_service.dart';

/// Thin wrapper around Razorpay SDK.
/// Consumers set [onSuccess] / [onFailure] before calling [openCheckout].
/// Call [dispose] when the owning widget is removed.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Razorpay? _rp;

  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onFailure;
  Function(ExternalWalletResponse)? onWallet;

  bool get isInitialized => _rp != null;

  void initialize() {
    _rp?.clear();
    _rp = Razorpay();
    _rp!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _rp!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure);
    _rp!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  void dispose() {
    _rp?.clear();
    _rp = null;
    onSuccess = null;
    onFailure = null;
    onWallet = null;
  }

  // ── One-time checkout ───────────────────────────────────────────────────

  /// [amountPaise] — amount in paise (₹1 = 100 paise)
  void openCheckout({
    required int amountPaise,
    required String description,
    required String phone,
    String? email,
    String? riderId,
    String? planType,
    String paymentType = 'onboarding',
  }) {
    assert(isInitialized,
        'Call PaymentService().initialize() before openCheckout()');
    final options = <String, dynamic>{
      'key': Env.razorpayKeyId,
      'amount': amountPaise,
      'name': 'RainCheck',
      'description': description,
      'prefill': {
        'contact': phone,
        if (email != null) 'email': email,
      },
      'theme': {'color': '#3B82F6'},
      'notes': {
        if (riderId != null) 'rider_id': riderId,
        if (planType != null) 'plan': planType,
        'payment_type': paymentType,
      },
    };
    _rp!.open(options);
  }

  // ── Subscription checkout ───────────────────────────────────────────────

  /// Opens Razorpay with a pre-created [subscriptionId].
  void openSubscriptionCheckout({
    required String subscriptionId,
    required String description,
    required String phone,
    String? email,
  }) {
    assert(isInitialized,
        'Call PaymentService().initialize() before openSubscriptionCheckout()');
    final options = <String, dynamic>{
      'key': Env.razorpayKeyId,
      'subscription_id': subscriptionId,
      'name': 'RainCheck Weekly',
      'description': description,
      'prefill': {
        'contact': phone,
        if (email != null) 'email': email,
      },
      'theme': {'color': '#3B82F6'},
    };
    _rp!.open(options);
  }

  // ── Verification ────────────────────────────────────────────────────────

  Future<bool> verifyPayment(PaymentSuccessResponse r) async {
    final res = await ApiService().verifyPayment({
      'razorpay_payment_id': r.paymentId,
      'razorpay_order_id': r.orderId,
      'razorpay_signature': r.signature,
    });
    return res.success;
  }

  // ── Internal handlers ───────────────────────────────────────────────────

  void _handleSuccess(PaymentSuccessResponse r) => onSuccess?.call(r);
  void _handleFailure(PaymentFailureResponse r) => onFailure?.call(r);
  void _handleWallet(ExternalWalletResponse r) => onWallet?.call(r);
}
