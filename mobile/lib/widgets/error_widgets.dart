import 'package:flutter/material.dart';
import '../core/theme.dart';

// ── Generic network error screen ──────────────────────────────────────────────

class NetworkErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const NetworkErrorScreen({
    super.key,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 64, color: RainCheckTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No connection',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: RainCheckTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: RainCheckTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                  backgroundColor: RainCheckTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline API error banner ───────────────────────────────────────────────────

class ApiErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ApiErrorBanner({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RainCheckTheme.error.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RainCheckTheme.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: RainCheckTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _friendlyMessage(error),
              style: const TextStyle(
                  color: RainCheckTheme.error, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: RainCheckTheme.error)),
            ),
        ],
      ),
    );
  }

  String _friendlyMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('network') || lower.contains('connection') ||
        lower.contains('socket')) {
      return 'Unable to reach server. Please check your connection.';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'The requested resource was not found.';
    }
    if (lower.contains('500') || lower.contains('server')) {
      return 'Server error. Our team has been notified.';
    }
    if (lower.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
  }
}

// ── GPS permission denied ─────────────────────────────────────────────────────

class GpsPermissionDeniedScreen extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const GpsPermissionDeniedScreen(
      {super.key, required this.onRequestPermission});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded,
                size: 64, color: RainCheckTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Location required',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'RainCheck needs your location to show nearby hazard alerts and '
              'calculate accurate weather risks for your route.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RainCheckTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRequestPermission,
              icon: const Icon(Icons.location_on),
              label: const Text('Allow Location'),
              style: FilledButton.styleFrom(
                  backgroundColor: RainCheckTheme.primary),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now',
                  style: TextStyle(color: RainCheckTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera permission denied ──────────────────────────────────────────────────

class CameraPermissionDeniedScreen extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final VoidCallback onPickFromGallery;

  const CameraPermissionDeniedScreen({
    super.key,
    required this.onRequestPermission,
    required this.onPickFromGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded,
                size: 64, color: RainCheckTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Camera access needed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'To upload evidence photos for your claim, we need camera access. '
              'You can also pick an existing photo from your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RainCheckTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRequestPermission,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Allow Camera'),
              style: FilledButton.styleFrom(
                  backgroundColor: RainCheckTheme.primary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment failure screen ────────────────────────────────────────────────────

class PaymentFailureScreen extends StatelessWidget {
  final String? reason;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const PaymentFailureScreen({
    super.key,
    this.reason,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: RainCheckTheme.error.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payment_rounded,
                      size: 40, color: RainCheckTheme.error),
                ),
                const SizedBox(height: 20),
                Text('Payment failed',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  reason ?? 'Your payment could not be processed. '
                      'No amount has been deducted.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RainCheckTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                      backgroundColor: RainCheckTheme.primary,
                      minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48)),
                  child: const Text('Cancel',
                      style: TextStyle(color: RainCheckTheme.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Crash detection overlay ───────────────────────────────────────────────────

class CrashDetectionOverlay extends StatefulWidget {
  const CrashDetectionOverlay({super.key});

  @override
  State<CrashDetectionOverlay> createState() => _CrashDetectionOverlayState();
}

class _CrashDetectionOverlayState extends State<CrashDetectionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _countdown = 30;
  late final Stream<int> _timer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Stream.periodic(const Duration(seconds: 1), (i) => 29 - i)
        .take(30);
    _timer.listen((remaining) {
      if (mounted) setState(() => _countdown = remaining);
      if (remaining <= 0 && mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: RainCheckTheme.error
                      .withAlpha((_pulse.value * 80).toInt() + 40),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 40, color: RainCheckTheme.error),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Crash Detected',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: RainCheckTheme.error)),
            const SizedBox(height: 8),
            Text(
              'Are you okay? Emergency services will be alerted in $_countdown seconds.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: RainCheckTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                  backgroundColor: RainCheckTheme.success,
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text("I'm okay — cancel alert"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: RainCheckTheme.error),
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text('Send SOS now',
                  style: TextStyle(color: RainCheckTheme.error)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state placeholder ───────────────────────────────────────────────────

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: RainCheckTheme.surfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: RainCheckTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RainCheckTheme.textSecondary)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                    backgroundColor: RainCheckTheme.primary),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
