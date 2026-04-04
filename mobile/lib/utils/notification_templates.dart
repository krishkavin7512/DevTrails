/// Notification payload builders — used both for local display and
/// for constructing FCM payloads sent from the backend.
class NotificationTemplates {
  const NotificationTemplates._();

  // ── 1. Trigger / disruption alert ──────────────────────────────────────────

  static Map<String, String> triggerAlert({
    required String triggerType,
    required String zone,
    String? city,
  }) =>
      {
        'title': '⚡ Trigger Alert',
        'body':  '$triggerType detected in $zone'
            '${city != null ? ', $city' : ''}. '
            'Your coverage is active.',
        'type': 'trigger_alert',
      };

  // ── 2. Claim approved ───────────────────────────────────────────────────────

  static Map<String, String> claimApproved({
    required String claimNumber,
    required int payoutPaise,
    String? upiId,
  }) {
    final amt = '₹${(payoutPaise / 100).toStringAsFixed(0)}';
    return {
      'title': '✅ Claim Approved',
      'body':  'Claim $claimNumber approved. $amt payout initiated'
          '${upiId != null ? ' to $upiId' : ''}.',
      'type': 'claim_approved',
    };
  }

  // ── 3. Payment success ─────────────────────────────────────────────────────

  static Map<String, String> paymentSuccess({
    required int amountPaise,
    required String nextDateStr,
  }) {
    final amt = '₹${(amountPaise / 100).toStringAsFixed(0)}';
    return {
      'title': '💳 Premium Received',
      'body':  '$amt collected. Coverage active until $nextDateStr.',
      'type': 'payment_success',
    };
  }

  // ── 4. Payment failed ──────────────────────────────────────────────────────

  static Map<String, String> paymentFailed({
    required int amountPaise,
    required String graceEndsAt,
  }) {
    final amt = '₹${(amountPaise / 100).toStringAsFixed(0)}';
    return {
      'title': '⚠️ Payment Failed',
      'body':  'Weekly premium of $amt failed. 12-hour grace period active '
          '(until $graceEndsAt). Update payment to keep coverage.',
      'type': 'payment_failed',
    };
  }

  // ── 5. Welcome message ─────────────────────────────────────────────────────

  static Map<String, String> welcome({required String firstName}) => {
        'title': '👋 Welcome to RainCheck',
        'body':  'Hi $firstName! Complete onboarding to activate '
            'your weather coverage.',
        'type': 'welcome',
      };

  // ── 6. Panic / emergency alert ─────────────────────────────────────────────

  static Map<String, String> panicAlert({
    required String riderName,
    required double distanceKm,
  }) =>
      {
        'title': '🚨 Emergency Alert',
        'body':  '$riderName needs help '
            '${distanceKm.toStringAsFixed(1)} km away. '
            'Tap to view location.',
        'type': 'panic_alert',
      };

  // ── 7. Predictive / forecast alert ─────────────────────────────────────────

  static Map<String, String> predictiveAlert({
    required String triggerType,
    required String zone,
    required String forecastTime,
  }) =>
      {
        'title': '🔮 Forecast Alert',
        'body':  '$triggerType forecast for $zone at $forecastTime. '
            'Consider adjusting your schedule.',
        'type': 'predictive_alert',
      };

  // ── WhatsApp message bodies (longer form) ──────────────────────────────────

  static String whatsappTriggerAlert({
    required String name,
    required String triggerType,
    required String zone,
  }) =>
      '🌧️ Hi $name, $triggerType has been detected in $zone.\n\n'
      'Your RainCheck coverage is active. If eligible, a claim will be '
      'auto-initiated within the hour.\n\nStay safe on the road! 🛵';

  static String whatsappClaimApproved({
    required String name,
    required String claimNumber,
    required int payoutPaise,
    required String upiId,
  }) {
    final amt = '₹${(payoutPaise / 100).toStringAsFixed(0)}';
    return '✅ Hi $name, Claim #$claimNumber has been approved.\n\n'
        '$amt payout is being transferred to $upiId.\n'
        'ETA: 2–5 minutes.\n\n'
        'Thank you for riding with RainCheck! 🛵';
  }

  static String whatsappPaymentFailed({
    required String name,
    required int amountPaise,
    required String graceEndsAt,
  }) {
    final amt = '₹${(amountPaise / 100).toStringAsFixed(0)}';
    return '⚠️ Hi $name, your weekly RainCheck premium of $amt failed.\n\n'
        '🕐 You have a 12-hour grace period (until $graceEndsAt) to '
        'update your payment method.\n\n'
        'Open the app to retry: raincheck://pay\n\n'
        'If unpaid, your coverage will be paused.';
  }
}
