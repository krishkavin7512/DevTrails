import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/onboarding_provider.dart';
import '../../services/api_service.dart';
import 'onboarding_widgets.dart';

class Step4RiskAssessment extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step4RiskAssessment({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<Step4RiskAssessment> createState() => _Step4State();
}

class _Step4State extends ConsumerState<Step4RiskAssessment>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _meterAnim;

  bool _loading = true;
  String? _error;
  String _riskTier = '';
  List<String> _factors = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _meterAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _runAssessment();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAssessment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(onboardingProvider.notifier);
    final features = notifier.buildMLFeatures();

    double score = 50;
    String tier = 'Medium';
    List<String> factors = [];
    int? premiumPaise;

    try {
      // Call risk assessment
      final riskRes = await ApiService().getRiskAssessment(features);
      if (riskRes.success && riskRes.data != null) {
        final d = riskRes.data!;
        score = (d['risk_score'] as num?)?.toDouble() ?? 50.0;
        tier = d['risk_tier'] as String? ?? _scoreTier(score);
        factors = List<String>.from(d['risk_factors'] ?? []);
      } else {
        // Fallback local estimate
        score = _localRiskScore(features);
        tier = _scoreTier(score);
        factors = _localFactors(features);
      }

      // Also fetch recommended premium
      final premRes = await ApiService().getPremiumPrediction(features);
      if (premRes.success && premRes.data != null) {
        // ML returns premium_paise directly, or premium_inr as fallback
        final paise = (premRes.data!['premium_paise'] as num?)?.toInt();
        final inr   = (premRes.data!['premium_inr'] as num?)?.toDouble();
        premiumPaise = paise ?? (inr != null ? (inr * 100).round() : null);
      }
    } catch (_) {
      score = _localRiskScore(features);
      tier = _scoreTier(score);
      factors = _localFactors(features);
    }

    notifier.setRiskResult(
      riskScore: score,
      riskTier: tier,
      riskFactors: factors,
      recommendedPremiumPaise: premiumPaise,
    );

    if (mounted) {
      setState(() {
        _riskTier = tier;
        _factors = factors;
        _loading = false;
      });
      // Tween animation to actual score
      _meterAnim = Tween<double>(
        begin: 0,
        end: score / 100,
      ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
      _animCtrl.forward();
    }
  }

  // ── Fallback local logic ────────────────────────────────────────────────────

  double _localRiskScore(Map<String, dynamic> f) {
    double s = 40;
    final exp = (f['experience_months'] as num?)?.toDouble() ?? 12;
    final hours = (f['avg_daily_hours'] as num?)?.toDouble() ?? 8;
    final vehicle = f['vehicle_type'] as String? ?? 'scooter';
    final shift = f['preferred_shift'] as String? ?? 'mixed';
    if (exp < 6) s += 20;
    if (exp < 12) s += 10;
    if (hours > 10) s += 10;
    if (vehicle == 'motorcycle') s += 5;
    if (shift == 'night') s += 10;
    return s.clamp(10, 95);
  }

  String _scoreTier(double s) {
    if (s < 30) return 'Low';
    if (s < 55) return 'Medium';
    if (s < 75) return 'High';
    return 'VeryHigh';
  }

  List<String> _localFactors(Map<String, dynamic> f) {
    final out = <String>[];
    final exp = (f['experience_months'] as num?)?.toDouble() ?? 12;
    final hours = (f['avg_daily_hours'] as num?)?.toDouble() ?? 8;
    final shift = f['preferred_shift'] as String? ?? 'mixed';
    if (exp < 12) out.add('Limited delivery experience');
    if (hours > 10) out.add('Long hours increase fatigue risk');
    if (shift == 'night') out.add('Night shifts carry higher risk');
    if (out.isEmpty) out.add('Low weather disruption history for your zone');
    return out;
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Low':
        return RainCheckTheme.success;
      case 'Medium':
        return RainCheckTheme.warning;
      case 'High':
        return const Color(0xFFF97316);
      default:
        return RainCheckTheme.error;
    }
  }

  String _tierLabel(String tier) {
    if (tier == 'VeryHigh') return 'Very High Risk';
    return '$tier Risk';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Assessment',
            style: TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Our ML model analyses your profile and local weather patterns',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          if (_loading) _buildLoading() else _buildResult(),

          if (_error != null) ErrorBanner(_error!),

          if (!_loading) ...[
            const SizedBox(height: 32),
            NavRow(onBack: widget.onBack, onNext: widget.onNext),
          ],
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const CircularProgressIndicator(color: RainCheckTheme.primary),
          const SizedBox(height: 24),
          const Text(
            'Analysing your risk profile…',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking weather data for your zone',
            style: TextStyle(
              color: RainCheckTheme.textSecondary.withAlpha(150),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final color = _tierColor(_riskTier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated risk meter
        SizedBox(
          height: 200,
          child: AnimatedBuilder(
            animation: _meterAnim,
            builder: (_, __) => CustomPaint(
              painter: _RiskMeterPainter(
                progress: _meterAnim.value,
                color: color,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_meterAnim.value * 100).round()}',
                        style: TextStyle(
                          color: color,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'out of 100',
                        style: TextStyle(
                          color: RainCheckTheme.textSecondary.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Tier badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Text(
              _tierLabel(_riskTier),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Risk factors
        const OLabel('Key Risk Factors'),
        const SizedBox(height: 12),
        ..._factors.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f,
                    style: const TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RainCheckTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RainCheckTheme.surfaceVariant),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: RainCheckTheme.textSecondary,
                size: 18,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your risk score determines your premium. '
                  'Lower score = lower weekly cost.',
                  style: TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Risk Meter CustomPainter ───────────────────────────────────────────────────

class _RiskMeterPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  const _RiskMeterPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final radius = size.width * 0.38;
    const strokeW = 18.0;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(18)
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background arc (full semicircle)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Segment tint arcs: green→yellow→orange→red
    _drawSegment(
      canvas,
      cx,
      cy,
      radius,
      math.pi,
      math.pi * 0.25,
      RainCheckTheme.success.withAlpha(40),
      strokeW - 2,
    );
    _drawSegment(
      canvas,
      cx,
      cy,
      radius,
      math.pi * 1.25,
      math.pi * 0.25,
      RainCheckTheme.warning.withAlpha(40),
      strokeW - 2,
    );
    _drawSegment(
      canvas,
      cx,
      cy,
      radius,
      math.pi * 1.5,
      math.pi * 0.25,
      const Color(0xFFF97316).withAlpha(40),
      strokeW - 2,
    );
    _drawSegment(
      canvas,
      cx,
      cy,
      radius,
      math.pi * 1.75,
      math.pi * 0.25,
      RainCheckTheme.error.withAlpha(40),
      strokeW - 2,
    );

    // Foreground progress arc
    if (progress > 0.01) {
      final fgPaint = Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        math.pi,
        math.pi * progress,
        false,
        fgPaint,
      );
    }

    // Needle tip dot
    final angle = math.pi + math.pi * progress;
    final nx = cx + radius * math.cos(angle);
    final ny = cy + radius * math.sin(angle);
    canvas.drawCircle(Offset(nx, ny), strokeW / 2 + 2, Paint()..color = color);
    canvas.drawCircle(
      Offset(nx, ny),
      strokeW / 2 - 2,
      Paint()..color = Colors.white,
    );

    // Labels
    TextPainter tp(String t, Color c) {
      final span = TextSpan(
        text: t,
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600),
      );
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr);
      painter.layout();
      return painter;
    }

    final low = tp('LOW', RainCheckTheme.success);
    low.paint(canvas, Offset(cx - radius - 4, cy + 8));
    final high = tp('HIGH', RainCheckTheme.error);
    high.paint(canvas, Offset(cx + radius - 16, cy + 8));
  }

  void _drawSegment(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double start,
    double sweep,
    Color color,
    double width,
  ) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RiskMeterPainter old) =>
      old.progress != progress || old.color != color;
}
