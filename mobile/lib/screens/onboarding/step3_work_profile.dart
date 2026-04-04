import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../services/api_service.dart';
import 'onboarding_widgets.dart';

class Step3WorkProfile extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step3WorkProfile({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<Step3WorkProfile> createState() => _Step3State();
}

class _Step3State extends ConsumerState<Step3WorkProfile> {
  double _earningsK = 4.0; // ₹ thousands (2–8)
  double _hours = 8;
  double _expMonths = 12;
  String _vehicle = 'Scooter';
  String _shift = 'Mixed';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingProvider);
    _earningsK = (d.weeklyEarningsPaise / 100000).clamp(2.0, 8.0);
    _hours = d.dailyHours.toDouble().clamp(4.0, 14.0);
    _expMonths = d.experienceMonths.toDouble().clamp(1.0, 60.0);
    _vehicle = d.vehicleType;
    _shift = d.preferredShift;
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notifier = ref.read(onboardingProvider.notifier);
      notifier.updateWorkProfile(
        weeklyEarningsPaise: (_earningsK * 100000).round(),
        dailyHours: _hours.round(),
        experienceMonths: _expMonths.round(),
        vehicleType: _vehicle,
        preferredShift: _shift,
      );

      // PATCH rider with complete profile so ML gets accurate data
      final riderId = ref.read(riderIdProvider);
      if (riderId != null) {
        final phone = ref.read(authProvider).riderId ?? '';
        final payload = notifier.buildRiderUpdatePayload(phone);
        await ApiService().updateRider(riderId, payload);
      }

      widget.onNext();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your work profile',
            style: TextStyle(
              color: RainCheckTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Helps us calculate your income risk accurately',
            style: TextStyle(color: RainCheckTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 28),

          // Weekly earnings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const OLabel('Weekly Earnings'),
              Text(
                '₹${_earningsK.toStringAsFixed(1)}k',
                style: const TextStyle(
                  color: RainCheckTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Slider(
            value: _earningsK,
            min: 2,
            max: 8,
            divisions: 24,
            activeColor: RainCheckTheme.primary,
            inactiveColor: RainCheckTheme.surfaceVariant,
            onChanged: (v) => setState(() => _earningsK = v),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹2k',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '₹8k',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Daily hours
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const OLabel('Daily Hours on Road'),
              Text(
                '${_hours.round()}h',
                style: const TextStyle(
                  color: RainCheckTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Slider(
            value: _hours,
            min: 4,
            max: 14,
            divisions: 10,
            activeColor: RainCheckTheme.primary,
            inactiveColor: RainCheckTheme.surfaceVariant,
            onChanged: (v) => setState(() => _hours = v),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '4h',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '14h',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Experience
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const OLabel('Delivery Experience'),
              Text(
                _expMonths < 12
                    ? '${_expMonths.round()}m'
                    : '${(_expMonths / 12).toStringAsFixed(1)}y',
                style: const TextStyle(
                  color: RainCheckTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          Slider(
            value: _expMonths,
            min: 1,
            max: 60,
            divisions: 59,
            activeColor: RainCheckTheme.primary,
            inactiveColor: RainCheckTheme.surfaceVariant,
            onChanged: (v) => setState(() => _expMonths = v),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1m',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                '5y',
                style: TextStyle(
                  color: RainCheckTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Vehicle type
          const OLabel('Vehicle Type'),
          const SizedBox(height: 12),
          Row(
            children:
                [
                  ('Bicycle', Icons.directions_bike),
                  ('Scooter', Icons.electric_scooter),
                  ('Motorcycle', Icons.two_wheeler),
                ].map((e) {
                  final sel = _vehicle == e.$1;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _vehicle = e.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: sel
                              ? RainCheckTheme.primary.withAlpha(25)
                              : RainCheckTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? RainCheckTheme.primary
                                : RainCheckTheme.surfaceVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              e.$2,
                              color: sel
                                  ? RainCheckTheme.primary
                                  : RainCheckTheme.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.$1,
                              style: TextStyle(
                                color: sel
                                    ? RainCheckTheme.textPrimary
                                    : RainCheckTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),

          // Preferred shift
          const OLabel('Preferred Shift'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Morning', 'Afternoon', 'Evening', 'Night', 'Mixed'].map(
              (s) {
                final sel = _shift == s;
                return GestureDetector(
                  onTap: () => setState(() => _shift = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? RainCheckTheme.primary.withAlpha(25)
                          : RainCheckTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? RainCheckTheme.primary
                            : RainCheckTheme.surfaceVariant,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        color: sel
                            ? RainCheckTheme.primary
                            : RainCheckTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),

          if (_error != null) ErrorBanner(_error!),
          const SizedBox(height: 32),

          NavRow(onBack: widget.onBack, onNext: _submit, loading: _saving),
        ],
      ),
    );
  }
}
