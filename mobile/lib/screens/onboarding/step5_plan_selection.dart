import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/onboarding_provider.dart';
import 'onboarding_widgets.dart';

// ── Plan definitions ───────────────────────────────────────────────────────────

class _Plan {
  final String name;
  final String tagline;
  final double premiumMultiplier;
  final int coverageLimitPaise; // e.g. 500000 = ₹5 000/week max
  final List<String> triggers;
  final Color accent;

  const _Plan({
    required this.name,
    required this.tagline,
    required this.premiumMultiplier,
    required this.coverageLimitPaise,
    required this.triggers,
    required this.accent,
  });
}

const _plans = [
  _Plan(
    name: 'Basic',
    tagline: 'Essential rain cover',
    premiumMultiplier: 0.6,
    coverageLimitPaise: 500000,
    triggers: ['HeavyRain', 'Flooding'],
    accent: RainCheckTheme.success,
  ),
  _Plan(
    name: 'Standard',
    tagline: 'Recommended for most riders',
    premiumMultiplier: 1.0,
    coverageLimitPaise: 800000,
    triggers: ['HeavyRain', 'Flooding', 'ExtremeHeat', 'SevereAQI'],
    accent: RainCheckTheme.primary,
  ),
  _Plan(
    name: 'Premium',
    tagline: 'Full protection, all hazards',
    premiumMultiplier: 1.5,
    coverageLimitPaise: 1200000,
    triggers: [
      'HeavyRain',
      'Flooding',
      'ExtremeHeat',
      'SevereAQI',
      'ExtremeCold',
      'Hailstorm',
    ],
    accent: Color(0xFF8B5CF6),
  ),
];

// Fallback base premiums (paise) when ML returns nothing, keyed by riskTier
const _fallbackPremiums = {
  'Low': 19900,
  'Medium': 29900,
  'High': 49900,
  'VeryHigh': 69900,
};

// ── Screen ─────────────────────────────────────────────────────────────────────

class Step5PlanSelection extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step5PlanSelection({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<Step5PlanSelection> createState() => _Step5State();
}

class _Step5State extends ConsumerState<Step5PlanSelection> {
  String _selected = 'Standard';
  int? _expandedBreakdown; // index of expanded "Why this price?" card

  int _basePremium(OnboardingData d) {
    if (d.recommendedPremiumPaise != null && d.recommendedPremiumPaise! > 0) {
      return d.recommendedPremiumPaise!;
    }
    return _fallbackPremiums[d.riskTier ?? 'Medium'] ?? 29900;
  }

  String _recommendedPlan(String? tier) {
    switch (tier) {
      case 'Low':
        return 'Basic';
      case 'High':
      case 'VeryHigh':
        return 'Premium';
      default:
        return 'Standard';
    }
  }

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingProvider);
    _selected = d.selectedPlan ?? _recommendedPlan(d.riskTier);
  }

  void _confirm() {
    final d = ref.read(onboardingProvider);
    final base = _basePremium(d);
    final plan = _plans.firstWhere((p) => p.name == _selected);
    final premium = (base * plan.premiumMultiplier).round();

    ref
        .read(onboardingProvider.notifier)
        .selectPlan(
          plan: _selected,
          weeklyPremium: premium,
          coverageLimit: plan.coverageLimitPaise,
          coveredDisruptions: plan.triggers,
        );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(onboardingProvider);
    final base = _basePremium(d);
    final recommended = _recommendedPlan(d.riskTier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your plan',
            style: TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Premiums are calculated from your risk profile',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          ..._plans.asMap().entries.map((entry) {
            final i = entry.key;
            final plan = entry.value;
            final premium = (base * plan.premiumMultiplier).round();
            final isSelected = _selected == plan.name;
            final isRecommended = plan.name == recommended;
            final isExpanded = _expandedBreakdown == i;

            return _PlanCard(
              plan: plan,
              weeklyPremiumPaise: premium,
              selected: isSelected,
              recommended: isRecommended,
              breakdownExpanded: isExpanded,
              basePremiumPaise: base,
              onSelect: () => setState(() => _selected = plan.name),
              onToggleBreakdown: () =>
                  setState(() => _expandedBreakdown = isExpanded ? null : i),
            );
          }),

          const SizedBox(height: 8),
          _SelectedSummary(
            plan: _plans.firstWhere((p) => p.name == _selected),
            weeklyPremiumPaise:
                (base *
                        _plans
                            .firstWhere((p) => p.name == _selected)
                            .premiumMultiplier)
                    .round(),
          ),
          const SizedBox(height: 24),

          NavRow(
            onBack: widget.onBack,
            onNext: _confirm,
            nextLabel: 'Confirm Plan',
          ),
        ],
      ),
    );
  }
}

// ── Plan card ──────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final int weeklyPremiumPaise;
  final int basePremiumPaise;
  final bool selected;
  final bool recommended;
  final bool breakdownExpanded;
  final VoidCallback onSelect;
  final VoidCallback onToggleBreakdown;

  const _PlanCard({
    required this.plan,
    required this.weeklyPremiumPaise,
    required this.basePremiumPaise,
    required this.selected,
    required this.recommended,
    required this.breakdownExpanded,
    required this.onSelect,
    required this.onToggleBreakdown,
  });

  String _fmt(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: selected ? plan.accent.withAlpha(18) : RainCheckTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? plan.accent : RainCheckTheme.surfaceVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plan.name,
                                  style: TextStyle(
                                    color: plan.accent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (recommended) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: plan.accent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Recommended',
                                      style: TextStyle(
                                        color: plan.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.tagline,
                              style: const TextStyle(
                                color: RainCheckTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(weeklyPremiumPaise),
                            style: const TextStyle(
                              color: RainCheckTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            '/week',
                            style: TextStyle(
                              color: RainCheckTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Coverage
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: RainCheckTheme.textSecondary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Up to ${_fmt(plan.coverageLimitPaise)}/week coverage',
                        style: const TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Triggers
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: plan.triggers
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: plan.accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: RainCheckTheme.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _triggerLabel(t),
                                  style: TextStyle(
                                    color: plan.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            // "Why this price?" expandable
            InkWell(
              onTap: onToggleBreakdown,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: RainCheckTheme.surfaceVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Why this price?',
                      style: TextStyle(
                        color: plan.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      breakdownExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: RainCheckTheme.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            if (breakdownExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BreakdownRow(
                      'Base premium (ML model)',
                      _fmt(basePremiumPaise),
                    ),
                    _BreakdownRow(
                      'Plan multiplier',
                      '× ${plan.premiumMultiplier.toStringAsFixed(1)}',
                    ),
                    const Divider(color: RainCheckTheme.surfaceVariant),
                    _BreakdownRow(
                      'Weekly premium',
                      _fmt(weeklyPremiumPaise),
                      bold: true,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Premium is auto-adjusted each renewal based on your claims history.',
                      style: TextStyle(
                        color: RainCheckTheme.textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _triggerLabel(String t) {
    const labels = {
      'HeavyRain': 'Heavy Rain',
      'Flooding': 'Flooding',
      'ExtremeHeat': 'Extreme Heat',
      'SevereAQI': 'Severe AQI',
      'ExtremeCold': 'Extreme Cold',
      'Hailstorm': 'Hailstorm',
    };
    return labels[t] ?? t;
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BreakdownRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: bold
                  ? RainCheckTheme.textPrimary
                  : RainCheckTheme.textSecondary,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: bold
                ? RainCheckTheme.textPrimary
                : RainCheckTheme.textSecondary,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _SelectedSummary extends StatelessWidget {
  final _Plan plan;
  final int weeklyPremiumPaise;
  const _SelectedSummary({
    required this.plan,
    required this.weeklyPremiumPaise,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: RainCheckTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: RainCheckTheme.surfaceVariant),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: RainCheckTheme.success, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${plan.name} plan selected — '
            '₹${(weeklyPremiumPaise / 100).toStringAsFixed(0)}/week',
            style: const TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
