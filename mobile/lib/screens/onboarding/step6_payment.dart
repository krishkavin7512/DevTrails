import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../config/environment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/rider_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../home_screen.dart';
import 'onboarding_widgets.dart';

class Step6Payment extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  const Step6Payment({super.key, required this.onBack});

  @override
  ConsumerState<Step6Payment> createState() => _Step6State();
}

class _Step6State extends ConsumerState<Step6Payment> {
  late Razorpay _razorpay;
  bool _paying = false;
  bool _creatingPolicy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Razorpay callbacks ────────────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _createPolicy(response.paymentId);
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() {
      _paying = false;
      _error = response.message ?? 'Payment failed. Please try again.';
    });
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    // External wallet selected — treat as pending; show confirmation
    setState(() => _paying = false);
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  void _startPayment() {
    final d = ref.read(onboardingProvider);
    if (d.selectedPlan == null || d.weeklyPremium == null) {
      setState(() => _error = 'No plan selected. Go back and choose a plan.');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });

    final options = {
      'key': Env.razorpayKeyId,
      'amount': d.weeklyPremium, // already in paise
      'name': 'RainCheck',
      'description':
          '${d.selectedPlan} Plan — weekly premium',
      'prefill': {
        'contact': ref.read(authProvider).riderId ?? '',
      },
      'theme': {'color': '#3B82F6'},
      'external': {
        'wallets': ['paytm', 'gpay'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _paying = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createPolicy(String? paymentId) async {
    setState(() => _creatingPolicy = true);
    try {
      final d = ref.read(onboardingProvider);
      final riderId = ref.read(riderIdProvider);

      if (riderId == null) throw Exception('Rider ID not found');

      final payload = {
        'riderId': riderId,
        'planType': d.selectedPlan,
        'weeklyPremium': d.weeklyPremium,
        'coverageLimit': d.coverageLimit,
        'coveredDisruptions': d.coveredDisruptions,
        'autoRenew': true,
        if (paymentId != null) 'paymentId': paymentId,
      };

      final res = await ApiService().createPolicy(payload);
      if (!res.success) {
        throw Exception(res.error ?? 'Policy creation failed');
      }

      // Mark onboarding complete
      ref.read(onboardingProvider.notifier).setPaymentComplete();
      await StorageService().setOnboardingDone();

      // Invalidate dashboard so HomeScreen fetches fresh data
      ref.invalidate(riderDashboardProvider);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _paying = false;
        _creatingPolicy = false;
        _error = e.toString();
      });
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(onboardingProvider);
    final plan = d.selectedPlan ?? '—';
    final premium = d.weeklyPremium ?? 0;
    final coverage = d.coverageLimit ?? 0;
    final triggers = d.coveredDisruptions;

    final busy = _paying || _creatingPolicy;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activate your policy',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('One weekly payment activates your parametric cover',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),

          // Plan summary card
          _SummaryCard(
            plan: plan,
            weeklyPremiumPaise: premium,
            coverageLimitPaise: coverage,
            triggers: triggers,
          ),

          const SizedBox(height: 20),

          // How it works
          _HowItWorks(),

          const SizedBox(height: 24),

          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 16),
          ],

          // Pay button
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: busy ? null : _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: RainCheckTheme.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 12),
                        Text(
                          _creatingPolicy
                              ? 'Activating policy…'
                              : 'Opening payment…',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Text(
                      'Pay ₹${(premium / 100).toStringAsFixed(0)}/week',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: busy ? null : widget.onBack,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: RainCheckTheme.surfaceVariant),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Change Plan',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary, fontSize: 15)),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'Secured by Razorpay · Auto-renews weekly · Cancel anytime',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RainCheckTheme.textSecondary.withAlpha(150),
                  fontSize: 11,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String plan;
  final int weeklyPremiumPaise;
  final int coverageLimitPaise;
  final List<String> triggers;
  const _SummaryCard({
    required this.plan,
    required this.weeklyPremiumPaise,
    required this.coverageLimitPaise,
    required this.triggers,
  });

  String _fmt(int p) => '₹${(p / 100).toStringAsFixed(0)}';

  String _triggerLabel(String t) {
    const m = {
      'HeavyRain': 'Heavy Rain',
      'Flooding': 'Flooding',
      'ExtremeHeat': 'Extreme Heat',
      'SevereAQI': 'Severe AQI',
      'ExtremeCold': 'Extreme Cold',
      'Hailstorm': 'Hailstorm',
    };
    return m[t] ?? t;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RainCheckTheme.primary.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$plan Plan',
                    style: const TextStyle(
                        color: RainCheckTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmt(weeklyPremiumPaise),
                      style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const Text('/week',
                      style: TextStyle(
                          color: RainCheckTheme.textSecondary, fontSize: 11)),
                ]),
              ],
            ),
            const SizedBox(height: 14),
            _row(Icons.shield_outlined,
                'Up to ${_fmt(coverageLimitPaise)}/week payout'),
            const SizedBox(height: 8),
            _row(Icons.bolt_outlined,
                'Auto-triggered — no claims needed'),
            const SizedBox(height: 8),
            _row(Icons.replay_outlined, 'Auto-renews every 7 days'),
            if (triggers.isNotEmpty) ...[
              const SizedBox(height: 14),
              const OLabel('Covered Disruptions'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: triggers
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                RainCheckTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_triggerLabel(t),
                              style: const TextStyle(
                                  color: RainCheckTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      );

  Widget _row(IconData icon, String text) => Row(children: [
        Icon(icon, color: RainCheckTheme.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: RainCheckTheme.textSecondary, fontSize: 13)),
      ]);
}

// ── How it works ───────────────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.cloud_outlined, 'Weather event occurs',
          'Rain, flood, heat, AQI — any covered trigger'),
      (Icons.sensors, 'Auto-detected',
          'Our system checks real-time sensor data'),
      (Icons.account_balance_wallet_outlined, 'Payout in minutes',
          'Money transferred to your account automatically'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RainCheckTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How payouts work',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: RainCheckTheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.$1,
                          color: RainCheckTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2,
                              style: const TextStyle(
                                  color: RainCheckTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(s.$3,
                              style: const TextStyle(
                                  color: RainCheckTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
