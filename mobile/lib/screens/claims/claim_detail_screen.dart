import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../models/claim.dart';
import '../../services/api_service.dart';
import 'upload_earnings_proof_screen.dart';

class ClaimDetailScreen extends StatefulWidget {
  final Claim claim;
  const ClaimDetailScreen({super.key, required this.claim});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  late Claim _claim;

  @override
  void initState() {
    super.initState();
    _claim = widget.claim;
    _refreshClaim();
  }

  Future<void> _refreshClaim() async {
    final res = await ApiService().getClaimById(_claim.id);
    if (res.success && res.data != null && mounted) {
      setState(() => _claim = res.data!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: Text(_claim.claimNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshClaim,
            tooltip: 'Refresh status',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: RainCheckTheme.primary,
        onRefresh: _refreshClaim,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusHeader(claim: _claim),
            const SizedBox(height: 16),
            _StatusTimeline(claim: _claim),
            const SizedBox(height: 16),
            _TriggerDetails(claim: _claim),
            const SizedBox(height: 16),
            if (_claim.fraudScore > 0) ...[
              _FraudScoreCard(claim: _claim),
              const SizedBox(height: 16),
            ],
            _PayoutDetails(claim: _claim),
            const SizedBox(height: 24),
            _ActionButtons(claim: _claim, onRefresh: _refreshClaim),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Status header ─────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final Claim claim;
  const _StatusHeader({required this.claim});

  static const _statusColors = {
    'Paid':           RainCheckTheme.success,
    'Approved':       RainCheckTheme.primary,
    'AutoInitiated':  RainCheckTheme.warning,
    'UnderReview':    Color(0xFF8B5CF6),
    'Rejected':       RainCheckTheme.error,
    'FraudSuspected': RainCheckTheme.error,
  };
  static const _triggerIcons = {
    'HeavyRain':        Icons.water_drop,
    'ExtremeHeat':      Icons.thermostat,
    'SevereAQI':        Icons.air,
    'Flooding':         Icons.flood,
    'SocialDisruption': Icons.warning_amber,
  };

  Color get _color =>
      _statusColors[claim.status] ?? RainCheckTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: RainCheckTheme.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _triggerIcons[claim.triggerType] ?? Icons.shield,
                  color: RainCheckTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _triggerLabel(claim.triggerType),
                      style: const TextStyle(
                          color: RainCheckTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: claim.claimNumber));
                        Toast.info(context, 'Claim number copied');
                      },
                      child: Row(
                        children: [
                          Text(claim.claimNumber,
                              style: const TextStyle(
                                  color: RainCheckTheme.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy,
                              size: 12,
                              color: RainCheckTheme.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    claim.payoutFormatted,
                    style: const TextStyle(
                        color: RainCheckTheme.success,
                        fontSize: 24,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _color.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      claim.status,
                      style: TextStyle(
                          color: _color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: RainCheckTheme.surfaceVariant, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetaItem(label: 'Filed', value: _fmtDate(claim.createdAt)),
              if (claim.processedAt != null)
                _MetaItem(
                    label: 'Processed',
                    value: _fmtDate(claim.processedAt!)),
              if (claim.paidAt != null)
                _MetaItem(label: 'Paid', value: _fmtDate(claim.paidAt!)),
              _MetaItem(
                  label: 'Hours lost',
                  value:
                      '${claim.estimatedLostHours.toStringAsFixed(1)}h'),
            ],
          ),
        ],
      ),
    );
  }

  String _triggerLabel(String t) => const {
        'HeavyRain':        'Heavy Rainfall',
        'ExtremeHeat':      'Extreme Heat',
        'SevereAQI':        'Severe AQI',
        'Flooding':         'Flooding',
        'SocialDisruption': 'Social Disruption',
      }[t] ??
      t;

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: RainCheckTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Status timeline ───────────────────────────────────────────────────────────

class _StatusTimeline extends StatelessWidget {
  final Claim claim;
  const _StatusTimeline({required this.claim});

  // (statusKey, label, icon)
  static const List<(String, String, IconData)> _steps = [
    ('AutoInitiated', 'Auto-Initiated', Icons.play_circle_outline),
    ('UnderReview',   'Fraud Check',    Icons.policy_outlined),
    ('Approved',      'Approved',       Icons.check_circle_outline),
    ('Paid',          'Paid',           Icons.payments_outlined),
  ];

  int get _currentStep {
    switch (claim.status) {
      case 'AutoInitiated':  return 0;
      case 'UnderReview':
      case 'FraudSuspected': return 1;
      case 'Approved':       return 2;
      case 'Paid':           return 3;
      default:               return -1; // Rejected
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;
    final rejected =
        claim.status == 'Rejected' || claim.status == 'FraudSuspected';

    return _SectionCard(
      title: 'Status Timeline',
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = !rejected && step > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: done
                    ? RainCheckTheme.success
                    : RainCheckTheme.surfaceVariant,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final (_, label, icon) = _steps[stepIdx];
          final done   = !rejected && step > stepIdx;
          final active = !rejected && step == stepIdx;
          final color  = done
              ? RainCheckTheme.success
              : active
                  ? RainCheckTheme.primary
                  : RainCheckTheme.surfaceVariant;

          return Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.normal)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Trigger details ───────────────────────────────────────────────────────────

class _TriggerDetails extends StatelessWidget {
  final Claim claim;
  const _TriggerDetails({required this.claim});

  @override
  Widget build(BuildContext context) {
    final td = claim.triggerData;
    return _SectionCard(
      title: 'Trigger Details',
      child: Column(
        children: [
          _DetailRow('Parameter', td.parameter),
          _DetailRow('Data Source', td.dataSource),
          _DetailRow('Threshold', td.threshold.toStringAsFixed(1)),
          _DetailRow('Actual Value', td.actualValue.toStringAsFixed(1)),
          _DetailRow(
              'Overage',
              '${td.overagePercent >= 0 ? '+' : ''}${td.overagePercent.toStringAsFixed(1)}%'),
          _DetailRow('Timestamp', _fmtDateTime(td.timestamp)),
          _DetailRow('Location',
              '${td.lat.toStringAsFixed(4)}, ${td.lng.toStringAsFixed(4)}'),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Fraud score card ──────────────────────────────────────────────────────────

class _FraudScoreCard extends StatelessWidget {
  final Claim claim;
  const _FraudScoreCard({required this.claim});

  Color get _scoreColor {
    if (claim.fraudScore <= 20) return RainCheckTheme.success;
    if (claim.fraudScore <= 50) return RainCheckTheme.warning;
    return RainCheckTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Fraud Assessment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Risk Score',
                        style: TextStyle(
                            color: RainCheckTheme.textSecondary,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${claim.fraudScore.toStringAsFixed(0)} / 100',
                      style: TextStyle(
                          color: _scoreColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _scoreColor.withAlpha(20),
                  border: Border.all(color: _scoreColor, width: 2),
                ),
                child: Center(
                  child: Icon(
                    claim.fraudScore > 50
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: _scoreColor,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: claim.fraudScore / 100,
              backgroundColor: RainCheckTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(_scoreColor),
              minHeight: 6,
            ),
          ),
          if (claim.fraudFlags.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Flags',
                style: TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: claim.fraudFlags.map((f) {
                final display = f
                    .replaceAll('_', ' ')
                    .replaceAll(':', ': ')
                    .toLowerCase();
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: RainCheckTheme.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: RainCheckTheme.error.withAlpha(60)),
                  ),
                  child: Text(display,
                      style: const TextStyle(
                          color: RainCheckTheme.error, fontSize: 11)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payout details ────────────────────────────────────────────────────────────

class _PayoutDetails extends StatelessWidget {
  final Claim claim;
  const _PayoutDetails({required this.claim});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Payout Details',
      child: Column(
        children: [
          _DetailRow('Payout Amount', claim.payoutFormatted),
          _DetailRow('Est. Hours Lost',
              '${claim.estimatedLostHours.toStringAsFixed(1)} hours'),
          _DetailRow(
              'Payout Status', claim.isPaid ? 'Transferred' : 'Pending'),
          if (claim.paidAt != null)
            _DetailRow('Paid On',
                '${claim.paidAt!.day}/${claim.paidAt!.month}/${claim.paidAt!.year}'),
        ],
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final Claim claim;
  final VoidCallback onRefresh;
  const _ActionButtons({required this.claim, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (claim.status == 'Rejected') ...[
          _PrimaryButton(
            label: 'Appeal This Decision',
            icon: Icons.gavel_outlined,
            color: RainCheckTheme.warning,
            onTap: () => _showAppealSheet(context),
          ),
          const SizedBox(height: 10),
        ],
        if (claim.status == 'UnderReview' ||
            claim.status == 'FraudSuspected') ...[
          _PrimaryButton(
            label: 'Upload Earnings Proof',
            icon: Icons.upload_file_outlined,
            color: RainCheckTheme.primary,
            onTap: () async {
              final uploaded = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UploadEarningsProofScreen(claim: claim)),
              );
              if (uploaded == true) onRefresh();
            },
          ),
          const SizedBox(height: 10),
        ],
        if (claim.isPaid) ...[
          _PrimaryButton(
            label: 'Download Receipt',
            icon: Icons.download_outlined,
            color: RainCheckTheme.success,
            onTap: () => _downloadReceipt(context),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _showAppealSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RainCheckTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _AppealSheet(claim: claim, onSubmitted: onRefresh),
    );
  }

  void _downloadReceipt(BuildContext context) {
    final receipt = '''
RAINCHECK CLAIM RECEIPT
━━━━━━━━━━━━━━━━━━━━━━━
Claim No:    ${claim.claimNumber}
Trigger:     ${claim.triggerType}
Amount:      ${claim.payoutFormatted}
Status:      ${claim.status}
Filed:       ${claim.createdAt.day}/${claim.createdAt.month}/${claim.createdAt.year}
${claim.paidAt != null ? 'Paid On:     ${claim.paidAt!.day}/${claim.paidAt!.month}/${claim.paidAt!.year}' : ''}
━━━━━━━━━━━━━━━━━━━━━━━
Fraud Score: ${claim.fraudScore.toStringAsFixed(0)}/100
''';
    Clipboard.setData(ClipboardData(text: receipt));
    Toast.success(context, 'Receipt copied to clipboard');
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Appeal sheet ──────────────────────────────────────────────────────────────

class _AppealSheet extends StatefulWidget {
  final Claim claim;
  final VoidCallback onSubmitted;
  const _AppealSheet({required this.claim, required this.onSubmitted});

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().length < 20) {
      setState(() =>
          _error = 'Please provide at least 20 characters of explanation.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final res = await ApiService().appealClaim(
        widget.claim.id, _ctrl.text.trim());

    setState(() => _submitting = false);
    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context);
      widget.onSubmitted();
      Toast.success(context, 'Appeal submitted — admin will review within 48h');
    } else {
      setState(() =>
          _error = res.error ?? 'Submission failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RainCheckTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Appeal Rejected Claim',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.claim.claimNumber,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              hintText:
                  'Explain why this claim should be reconsidered. Include any relevant context about the weather event, your delivery activity, and why the rejection was incorrect.',
              hintStyle: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13),
              hintMaxLines: 4,
              filled: true,
              fillColor: RainCheckTheme.surfaceVariant,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    color: RainCheckTheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: RainCheckTheme.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Appeal',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared section card & detail row ─────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RainCheckTheme.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
