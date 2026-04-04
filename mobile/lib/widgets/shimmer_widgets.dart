import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';

// ── Base shimmer box ──────────────────────────────────────────────────────────

class _ShimBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimBox({
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: RainCheckTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

Shimmer _wrap(Widget child) => Shimmer.fromColors(
      baseColor: RainCheckTheme.surfaceVariant,
      highlightColor: RainCheckTheme.surface,
      child: child,
    );

// ── Dashboard shimmer ─────────────────────────────────────────────────────────

class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Policy card placeholder
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: RainCheckTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),

          // Weather card
          Container(
            height: 76,
            decoration: BoxDecoration(
              color: RainCheckTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),

          // Minimap placeholder
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: RainCheckTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),

          // Section title
          const _ShimBox(width: 120, height: 18),
          const SizedBox(height: 12),

          // Claim cards × 3
          for (int i = 0; i < 3; i++) ...[
            _ClaimShimCard(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ClaimShimCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RainCheckTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            _ShimBox(width: 40, height: 40, radius: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimBox(width: 100, height: 13),
                  SizedBox(height: 6),
                  _ShimBox(width: 70, height: 11),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ShimBox(width: 60, height: 14),
                SizedBox(height: 6),
                _ShimBox(width: 50, height: 18, radius: 10),
              ],
            ),
          ],
        ),
      );
}

// ── Claims list shimmer ───────────────────────────────────────────────────────

class ClaimsListShimmer extends StatelessWidget {
  const ClaimsListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RainCheckTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Expanded(child: _ShimBox(height: 12)),
                  SizedBox(width: 60),
                  _ShimBox(width: 70, height: 20, radius: 10),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _ShimBox(width: 36, height: 36, radius: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimBox(width: 120, height: 14),
                        SizedBox(height: 5),
                        _ShimBox(width: 80, height: 11),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ShimBox(width: 50, height: 18),
                      SizedBox(height: 5),
                      _ShimBox(width: 40, height: 11),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile shimmer ───────────────────────────────────────────────────────────

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return _wrap(
      ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Center(child: _ShimBox(width: 88, height: 88, radius: 44)),
          const SizedBox(height: 12),
          const Center(child: _ShimBox(width: 140, height: 18)),
          const SizedBox(height: 6),
          const Center(child: _ShimBox(width: 100, height: 14)),
          const SizedBox(height: 24),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: RainCheckTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: RainCheckTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic card shimmer ──────────────────────────────────────────────────────

class CardShimmer extends StatelessWidget {
  final double height;
  final double borderRadius;
  const CardShimmer({super.key, this.height = 100, this.borderRadius = 14});

  @override
  Widget build(BuildContext context) => _wrap(
        Container(
          height: height,
          decoration: BoxDecoration(
            color: RainCheckTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      );
}
