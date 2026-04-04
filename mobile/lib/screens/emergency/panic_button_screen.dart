import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/emergency_provider.dart';
import 'emergency_active_screen.dart';

class PanicButtonScreen extends ConsumerWidget {
  const PanicButtonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(emergencyProvider);

    // Navigate to active screen when emergency fires
    ref.listen(emergencyProvider, (prev, next) {
      if (next.phase == EmergencyPhase.active &&
          prev?.phase != EmergencyPhase.active) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmergencyActiveScreen()),
        );
      }
    });

    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        backgroundColor: RainCheckTheme.background,
        title: const Text('Emergency SOS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(emergencyProvider.notifier).onLongPressCancel();
            ref.read(emergencyProvider.notifier).cancelCountdown();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: switch (st.phase) {
          EmergencyPhase.idle || EmergencyPhase.longPressing => _IdleView(
            progress: st.longPressProgress,
          ),
          EmergencyPhase.awaitingConfirm => const _ConfirmView(),
          EmergencyPhase.countdown => _CountdownView(
            seconds: st.countdownSeconds,
          ),
          EmergencyPhase.active => const SizedBox.shrink(),
          EmergencyPhase.crashDetected => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// ── Phase 1: Long-press idle view ─────────────────────────────────────────

class _IdleView extends ConsumerStatefulWidget {
  final double progress;
  const _IdleView({required this.progress});

  @override
  ConsumerState<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends ConsumerState<_IdleView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pressing = widget.progress > 0;
    final size = pressing ? 160.0 + widget.progress * 20 : 160.0;

    return Column(
      children: [
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Hold the button for 3 seconds to activate SOS',
            textAlign: TextAlign.center,
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 15),
          ),
        ),
        const Spacer(),
        Center(
          child: GestureDetector(
            onLongPressStart: (_) {
              HapticFeedback.heavyImpact();
              _pulse.stop();
              ref.read(emergencyProvider.notifier).onLongPressStart();
            },
            onLongPressEnd: (_) {
              _pulse.repeat(reverse: true);
              ref.read(emergencyProvider.notifier).onLongPressCancel();
            },
            onLongPressCancel: () {
              _pulse.repeat(reverse: true);
              ref.read(emergencyProvider.notifier).onLongPressCancel();
            },
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: pressing ? 1.0 : _scale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    if (!pressing)
                      Container(
                        width: size + 40,
                        height: size + 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RainCheckTheme.error.withAlpha(
                            (_glow.value * 25).toInt(),
                          ),
                        ),
                      ),
                    // Middle ring
                    if (!pressing)
                      Container(
                        width: size + 20,
                        height: size + 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: RainCheckTheme.error.withAlpha(
                            (_glow.value * 35).toInt(),
                          ),
                        ),
                      ),
                    // Button itself
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 80),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: RainCheckTheme.error.withAlpha(pressing ? 60 : 30),
                        border: Border.all(
                          color: RainCheckTheme.error,
                          width: pressing ? 4 : 3,
                        ),
                        boxShadow: pressing
                            ? [
                                BoxShadow(
                                  color: RainCheckTheme.error.withAlpha(80),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: RainCheckTheme.error.withAlpha(
                                    (_glow.value * 60).toInt(),
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (pressing)
                            SizedBox(
                              width: size - 16,
                              height: size - 16,
                              child: CircularProgressIndicator(
                                value: widget.progress,
                                strokeWidth: 5,
                                color: RainCheckTheme.error,
                                backgroundColor:
                                    RainCheckTheme.error.withAlpha(30),
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.sos,
                                color: RainCheckTheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pressing ? 'Hold…' : 'SOS',
                                style: const TextStyle(
                                  color: RainCheckTheme.error,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const Padding(padding: EdgeInsets.all(24), child: _HowItWorksRow()),
      ],
    );
  }
}

class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _Step(icon: Icons.touch_app, label: 'Hold 3s'),
      Icon(Icons.arrow_forward, color: RainCheckTheme.textSecondary, size: 16),
      _Step(icon: Icons.swipe_right, label: 'Swipe'),
      Icon(Icons.arrow_forward, color: RainCheckTheme.textSecondary, size: 16),
      _Step(icon: Icons.timer, label: '5s delay'),
      Icon(Icons.arrow_forward, color: RainCheckTheme.textSecondary, size: 16),
      _Step(icon: Icons.notification_important, label: 'Alert sent'),
    ],
  );
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Step({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: RainCheckTheme.textSecondary, size: 20),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: RainCheckTheme.textSecondary,
          fontSize: 10,
        ),
      ),
    ],
  );
}

// ── Phase 2: Swipe-to-confirm ─────────────────────────────────────────────

class _ConfirmView extends ConsumerStatefulWidget {
  const _ConfirmView();

  @override
  ConsumerState<_ConfirmView> createState() => _ConfirmViewState();
}

class _ConfirmViewState extends ConsumerState<_ConfirmView> {
  double _dragX = 0;
  static const _thumbWidth = 64.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final trackWidth = constraints.maxWidth - 48;
      final maxDrag = trackWidth - _thumbWidth - 8;
      final progress = (_dragX / maxDrag).clamp(0.0, 1.0);
      final confirmed = progress >= 0.95;

      return Column(
        children: [
          const SizedBox(height: 48),
          const Icon(Icons.warning_amber, color: RainCheckTheme.error, size: 56),
          const SizedBox(height: 24),
          const Text(
            'Swipe to send SOS',
            style: TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Slide the button to confirm your emergency',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          // Swipe slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: trackWidth,
              height: 72,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Track
                  Container(
                    width: trackWidth,
                    height: 72,
                    decoration: BoxDecoration(
                      color: RainCheckTheme.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: RainCheckTheme.error.withAlpha(80)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 80),
                      child: Center(
                        child: Text(
                          confirmed ? '✓ Release to send' : 'Slide to confirm →',
                          style: TextStyle(
                            color: RainCheckTheme.error.withAlpha(
                              confirmed ? 255 : 150,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Fill
                  Container(
                    width: _thumbWidth + _dragX + 4,
                    height: 72,
                    decoration: BoxDecoration(
                      color: RainCheckTheme.error.withAlpha(
                        (progress * 60).toInt(),
                      ),
                      borderRadius: BorderRadius.circular(36),
                    ),
                  ),
                  // Thumb
                  GestureDetector(
                    onHorizontalDragUpdate: (d) {
                      setState(() {
                        _dragX = (_dragX + d.delta.dx).clamp(0.0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      if (_dragX >= maxDrag * 0.95) {
                        HapticFeedback.heavyImpact();
                        ref.read(emergencyProvider.notifier).onSwipeConfirmed();
                      } else {
                        setState(() => _dragX = 0);
                      }
                    },
                    child: Transform.translate(
                      offset: Offset(_dragX + 4, 0),
                      child: Container(
                        width: _thumbWidth,
                        height: 64,
                        decoration: BoxDecoration(
                          color: RainCheckTheme.error,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(
                          Icons.double_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () =>
              ref.read(emergencyProvider.notifier).cancelFromConfirm(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 15),
          ),
        ),
          const Spacer(),
        ],
      );
    });
  }
}

// ── Phase 3: Countdown ────────────────────────────────────────────────────

class _CountdownView extends ConsumerWidget {
  final int seconds;
  const _CountdownView({required this.seconds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Text(
          'Sending SOS in…',
          style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 32),
        _PulsingCircle(seconds: seconds),
        const SizedBox(height: 32),
        const Text(
          'Notifying emergency contact\nand nearby riders',
          textAlign: TextAlign.center,
          style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        SizedBox(
          width: 200,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(emergencyProvider.notifier).cancelCountdown();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: RainCheckTheme.textSecondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: RainCheckTheme.textPrimary, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  final int seconds;
  const _PulsingCircle({required this.seconds});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RainCheckTheme.error.withAlpha(30),
        border: Border.all(color: RainCheckTheme.error, width: 4),
      ),
      child: Center(
        child: Text(
          '${widget.seconds}',
          style: const TextStyle(
            color: RainCheckTheme.error,
            fontSize: 72,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

// ── Crash detection overlay (shown over any screen) ───────────────────────

class CrashDetectionOverlay extends ConsumerWidget {
  const CrashDetectionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(emergencyProvider);
    if (st.phase != EmergencyPhase.crashDetected) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black.withAlpha(200),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: RainCheckTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: RainCheckTheme.error.withAlpha(120)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.car_crash,
                  color: RainCheckTheme.error,
                  size: 52,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Crash Detected',
                  style: TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you okay? If no response, help will be\nautomatically sent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                // Countdown arc
                _CrashCountdownArc(seconds: st.crashCountdownSeconds),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          ref.read(emergencyProvider.notifier).respondImFine();
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: RainCheckTheme.success),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "I'm Fine",
                          style: TextStyle(
                            color: RainCheckTheme.success,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          ref.read(emergencyProvider.notifier).respondGetHelp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RainCheckTheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Get Help',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrashCountdownArc extends StatelessWidget {
  final int seconds;
  const _CrashCountdownArc({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final progress = seconds / 30.0;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            color: RainCheckTheme.error,
            backgroundColor: RainCheckTheme.surfaceVariant,
          ),
          Text(
            '$seconds',
            style: const TextStyle(
              color: RainCheckTheme.error,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Utility: show crash overlay anywhere via Navigator overlay
void showCrashOverlayIfNeeded(BuildContext context, WidgetRef ref) {
  final phase = ref.read(emergencyProvider).phase;
  if (phase == EmergencyPhase.crashDetected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CrashDetectionOverlay(),
    );
  }
}
