import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/community_provider.dart';

class TrustScoreScreen extends ConsumerWidget {
  const TrustScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(communityProvider);

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        backgroundColor: RainCheckTheme.background,
        title: const Text(
          'Trust Score',
          style: TextStyle(color: RainCheckTheme.textPrimary),
        ),
        iconTheme: const IconThemeData(color: RainCheckTheme.textPrimary),
      ),
      body: st.loadingTrust
          ? const Center(
              child: CircularProgressIndicator(color: RainCheckTheme.primary),
            )
          : st.trustProfile == null
          ? const Center(
              child: Text(
                'No trust data available.',
                style: TextStyle(color: RainCheckTheme.textSecondary),
              ),
            )
          : _TrustBody(profile: st.trustProfile!),
    );
  }
}

class _TrustBody extends StatelessWidget {
  final TrustProfile profile;
  const _TrustBody({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GaugeCard(profile: profile),
          const SizedBox(height: 20),
          _StatsRow(profile: profile),
          const SizedBox(height: 20),
          const _HowItWorksCard(),
          if (profile.recentEvents.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecentEventsCard(events: profile.recentEvents),
          ],
        ],
      ),
    );
  }
}

// ── Gauge card ────────────────────────────────────────────────────────────

class _GaugeCard extends StatelessWidget {
  final TrustProfile profile;
  const _GaugeCard({required this.profile});

  Color get _tierColor => switch (profile.trustTier) {
    'TrustedReporter' => RainCheckTheme.success,
    'LowTrust' => RainCheckTheme.error,
    _ => RainCheckTheme.primary,
  };

  String get _tierLabel => switch (profile.trustTier) {
    'TrustedReporter' => 'Trusted Reporter',
    'LowTrust' => 'Low Trust',
    _ => 'Normal',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 180,
              height: 110,
              child: CustomPaint(
                painter: _GaugePainter(
                  score: profile.trustScore,
                  color: _tierColor,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${profile.trustScore}',
                      style: TextStyle(
                        color: _tierColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '/ 100',
                      style: TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _tierColor.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _tierColor.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    profile.trustTier == 'TrustedReporter'
                        ? Icons.verified
                        : profile.trustTier == 'LowTrust'
                        ? Icons.warning_amber
                        : Icons.person,
                    color: _tierColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tierLabel,
                    style: TextStyle(
                      color: _tierColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${profile.totalPoints} points earned',
              style: const TextStyle(
                color: RainCheckTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  const _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.9;
    final r = size.width * 0.46;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = RainCheckTheme.surfaceVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Score arc
    final progress = score / 100;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepAngle * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Needle dot
    final angle = math.pi + math.pi * progress;
    final dx = cx + r * math.cos(angle);
    final dy = cy + r * math.sin(angle);
    canvas.drawCircle(Offset(dx, dy), 7, Paint()..color = color);
    canvas.drawCircle(Offset(dx, dy), 4, Paint()..color = Colors.white);

    // Labels
    const labelStyle = TextStyle(
      color: RainCheckTheme.textSecondary,
      fontSize: 10,
    );
    _drawText(canvas, '0', Offset(cx - r - 4, cy + 2), labelStyle);
    _drawText(canvas, '100', Offset(cx + r - 16, cy + 2), labelStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}

// ── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final TrustProfile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatTile(
          label: 'Submitted',
          value: '${profile.alertsSubmitted}',
          icon: Icons.send,
          color: RainCheckTheme.primary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          label: 'Confirmed',
          value: '${profile.alertsConfirmed}',
          icon: Icons.check_circle_outline,
          color: RainCheckTheme.warning,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          label: 'Verified',
          value: '${profile.alertsVerified}',
          icon: Icons.verified,
          color: RainCheckTheme.success,
        ),
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: RainCheckTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── How it works ──────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  static const _rules = [
    _Rule(
      '+15 pts',
      'Alert verified by parametric data',
      Icons.verified,
      RainCheckTheme.success,
    ),
    _Rule(
      '+10 pts',
      'Alert confirmed by 3+ riders',
      Icons.people,
      RainCheckTheme.success,
    ),
    _Rule(
      '+5 pts',
      'Alert marked helpful',
      Icons.thumb_up_outlined,
      RainCheckTheme.success,
    ),
    _Rule(
      '−10 pts',
      'Alert expires with zero confirmations',
      Icons.timer_off_outlined,
      RainCheckTheme.error,
    ),
    _Rule(
      '−15 pts',
      'Alert flagged false by 5+ riders',
      Icons.flag_outlined,
      RainCheckTheme.error,
    ),
    _Rule(
      '−20 pts',
      'Alert contradicted by sensor data',
      Icons.sensors_off,
      RainCheckTheme.error,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How trust score works',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._rules.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(r.icon, color: r.color, size: 16),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: r.color.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.delta,
                        style: TextStyle(
                          color: r.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 12,
                        ),
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

class _Rule {
  final String delta, label;
  final IconData icon;
  final Color color;
  const _Rule(this.delta, this.label, this.icon, this.color);
}

// ── Recent events ─────────────────────────────────────────────────────────

class _RecentEventsCard extends StatelessWidget {
  final List<TrustEvent> events;
  const _RecentEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...events.map((e) {
              final isPos = e.delta >= 0;
              final color = isPos
                  ? RainCheckTheme.success
                  : RainCheckTheme.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.description,
                        style: const TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isPos ? '+' : ''}${e.delta}',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
