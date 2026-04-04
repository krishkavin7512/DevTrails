import 'package:flutter/services.dart';

/// Centralised haptic feedback helpers. Each call is fire-and-forget.
class Haptics {
  const Haptics._();

  /// Light tap — button presses, chip selects.
  static Future<void> light() =>
      HapticFeedback.lightImpact();

  /// Medium — confirm actions, pull-to-refresh trigger.
  static Future<void> medium() =>
      HapticFeedback.mediumImpact();

  /// Heavy — panic button long-press, emergency confirm.
  static Future<void> heavy() =>
      HapticFeedback.heavyImpact();

  /// Success notification pattern (vibrate twice).
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.lightImpact();
  }

  /// Error pattern (single heavy pulse).
  static Future<void> error() =>
      HapticFeedback.vibrate();

  /// Selection changed — dropdown / segmented control.
  static Future<void> selection() =>
      HapticFeedback.selectionClick();
}
