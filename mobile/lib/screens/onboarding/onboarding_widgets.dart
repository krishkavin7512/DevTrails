import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Section label used across all onboarding steps.
class OLabel extends StatelessWidget {
  final String text;
  const OLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: RainCheckTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3));
}

/// Primary CTA button used across all onboarding steps.
class OnboardingButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  const OnboardingButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: RainCheckTheme.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
        ),
      );
}

/// Back + Continue row used on steps 2–6.
class NavRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String nextLabel;
  final bool loading;
  const NavRow({
    super.key,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Continue',
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: RainCheckTheme.surfaceVariant),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: const Icon(Icons.arrow_back,
              color: RainCheckTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OnboardingButton(
              label: nextLabel, onTap: onNext, loading: loading),
        ),
      ]);
}

/// Animated selection tile (platform, vehicle, shift, etc.)
class SelectTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;
  const SelectTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? RainCheckTheme.primary.withAlpha(25)
                : RainCheckTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? RainCheckTheme.primary
                  : RainCheckTheme.surfaceVariant,
            ),
          ),
          child: Row(children: [
            Icon(icon,
                color: selected
                    ? RainCheckTheme.primary
                    : RainCheckTheme.textSecondary,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected
                              ? RainCheckTheme.textPrimary
                              : RainCheckTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: RainCheckTheme.textSecondary,
                            fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: RainCheckTheme.primary, size: 20),
          ]),
        ),
      );
}

/// Error banner.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RainCheckTheme.error.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: RainCheckTheme.error.withAlpha(80)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline,
              color: RainCheckTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: RainCheckTheme.error, fontSize: 13))),
        ]),
      );
}
