import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../models/claim.dart';
import '../../providers/claim_provider.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../core/app_transitions.dart';
import 'claim_detail_screen.dart';

class ClaimsListScreen extends ConsumerStatefulWidget {
  const ClaimsListScreen({super.key});

  @override
  ConsumerState<ClaimsListScreen> createState() => _ClaimsListScreenState();
}

class _ClaimsListScreenState extends ConsumerState<ClaimsListScreen> {
  String _filterStatus  = 'All';
  String _filterTrigger = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _statuses = [
    'All', 'AutoInitiated', 'UnderReview', 'Approved', 'Paid', 'Rejected', 'FraudSuspected',
  ];
  static const _triggers = [
    'All', 'HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Claim> _applyFilters(List<Claim> claims) {
    return claims.where((c) {
      if (_filterStatus != 'All' && c.status != _filterStatus) return false;
      if (_filterTrigger != 'All' && c.triggerType != _filterTrigger) return false;
      if (_searchQuery.isNotEmpty &&
          !c.claimNumber.toLowerCase().contains(_searchQuery.toLowerCase()) &&
          !c.id.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimsProvider);
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('My Claims'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(claimsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchCtrl, onChanged: (v) => setState(() => _searchQuery = v)),
          _FilterRow(
            selectedStatus:  _filterStatus,
            selectedTrigger: _filterTrigger,
            statuses:  _statuses,
            triggers:  _triggers,
            onStatusChanged:  (v) => setState(() => _filterStatus  = v),
            onTriggerChanged: (v) => setState(() => _filterTrigger = v),
          ),
          Expanded(
            child: state.when(
              loading: () => const ClaimsListShimmer(),
              error: (e, _) => _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(claimsProvider)),
              data: (claims) {
                final filtered = _applyFilters(claims);
                if (filtered.isEmpty) return const _EmptyState();
                return RefreshIndicator(
                  color: RainCheckTheme.primary,
                  onRefresh: () async {
                    await Haptics.medium();
                    ref.invalidate(claimsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _ClaimCard(claim: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: RainCheckTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by claim ID or number…',
          hintStyle: const TextStyle(color: RainCheckTheme.textSecondary),
          prefixIcon: const Icon(Icons.search, color: RainCheckTheme.textSecondary, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: RainCheckTheme.textSecondary, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: RainCheckTheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RainCheckTheme.surfaceVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RainCheckTheme.surfaceVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: RainCheckTheme.primary),
          ),
        ),
      ),
    );
  }
}

// ── Filter row ────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String selectedStatus;
  final String selectedTrigger;
  final List<String> statuses;
  final List<String> triggers;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTriggerChanged;

  const _FilterRow({
    required this.selectedStatus,
    required this.selectedTrigger,
    required this.statuses,
    required this.triggers,
    required this.onStatusChanged,
    required this.onTriggerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _DropdownFilter(
              label: 'Status',
              value: selectedStatus,
              items: statuses,
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DropdownFilter(
              label: 'Trigger',
              value: selectedTrigger,
              items: triggers,
              onChanged: onTriggerChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DropdownFilter(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RainCheckTheme.surfaceVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: RainCheckTheme.surface,
          style: const TextStyle(color: RainCheckTheme.textPrimary, fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: RainCheckTheme.textSecondary, size: 18),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ── Claim card ────────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  final Claim claim;
  const _ClaimCard({required this.claim});

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

  Color get _statusColor =>
      _statusColors[claim.status] ?? RainCheckTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RainCheckTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          SlideRightRoute(page: ClaimDetailScreen(claim: claim)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _statusColor.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: claim number + status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      claim.claimNumber,
                      style: const TextStyle(
                          color: RainCheckTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                  _StatusBadge(status: claim.status, color: _statusColor),
                ],
              ),
              const SizedBox(height: 12),

              // Trigger row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: RainCheckTheme.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _triggerIcons[claim.triggerType] ?? Icons.shield,
                      color: RainCheckTheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _triggerLabel(claim.triggerType),
                          style: const TextStyle(
                              color: RainCheckTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _timeAgo(claim.createdAt),
                          style: const TextStyle(
                              color: RainCheckTheme.textSecondary, fontSize: 12),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                      if (claim.fraudScore > 30)
                        Text(
                          'Fraud: ${claim.fraudScore.toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: claim.fraudScore > 60
                                  ? RainCheckTheme.error
                                  : RainCheckTheme.warning,
                              fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),

              // Appeal / upload proof CTA
              if (claim.status == 'Rejected' ||
                  claim.status == 'UnderReview' ||
                  claim.status == 'FraudSuspected') ...[
                const SizedBox(height: 10),
                const Divider(color: RainCheckTheme.surfaceVariant, height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      claim.status == 'Rejected'
                          ? Icons.gavel_outlined
                          : Icons.upload_file_outlined,
                      size: 14,
                      color: _statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      claim.status == 'Rejected'
                          ? 'Tap to file an appeal'
                          : 'Tap to upload earnings proof',
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: _statusColor, size: 16),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _triggerLabel(String t) {
    const map = {
      'HeavyRain':        'Heavy Rainfall',
      'ExtremeHeat':      'Extreme Heat',
      'SevereAQI':        'Severe AQI',
      'Flooding':         'Flooding',
      'SocialDisruption': 'Social Disruption',
    };
    return map[t] ?? t;
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 7) return '${dt.day}/${dt.month}/${dt.year}';
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    return '${d.inMinutes}m ago';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              color: RainCheckTheme.textSecondary, size: 56),
          SizedBox(height: 16),
          Text('No claims found',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('Claims are filed automatically\nwhen weather thresholds are crossed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: RainCheckTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: RainCheckTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
