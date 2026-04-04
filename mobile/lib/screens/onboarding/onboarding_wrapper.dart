import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/onboarding_provider.dart';
import 'step1_basic_info.dart';
import 'step2_location.dart';
import 'step3_work_profile.dart';
import 'step4_risk_assessment.dart';
import 'step5_plan_selection.dart';
import 'step6_payment.dart';

class OnboardingWrapper extends ConsumerStatefulWidget {
  /// Pre-populate from registration data (first-time flow).
  final String? initialName;
  final String? initialCity;
  final String? initialPlatform;
  final String? initialVehicle;

  const OnboardingWrapper({
    super.key,
    this.initialName,
    this.initialCity,
    this.initialPlatform,
    this.initialVehicle,
  });

  @override
  ConsumerState<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends ConsumerState<OnboardingWrapper> {
  final _pageController = PageController();
  int _currentStep = 0;

  static const _stepLabels = [
    'Basic Info',
    'Location',
    'Work Profile',
    'Risk Assessment',
    'Plan Selection',
    'Payment',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = ref.read(onboardingProvider);
      if (data.fullName.isEmpty && widget.initialName != null) {
        ref.read(onboardingProvider.notifier).initFromRegistration(
              fullName: widget.initialName!,
              city: widget.initialCity ?? '',
              platform: widget.initialPlatform ?? 'Zomato',
              vehicleType: widget.initialVehicle ?? 'Scooter',
            );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  Step1BasicInfo(onNext: _nextStep),
                  Step2Location(onNext: _nextStep, onBack: _prevStep),
                  Step3WorkProfile(onNext: _nextStep, onBack: _prevStep),
                  Step4RiskAssessment(onNext: _nextStep, onBack: _prevStep),
                  Step5PlanSelection(onNext: _nextStep, onBack: _prevStep),
                  Step6Payment(onBack: _prevStep),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentStep + 1} of 6',
                style: const TextStyle(
                    color: RainCheckTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Text(
                '— ${_stepLabels[_currentStep]}',
                style: const TextStyle(
                    color: RainCheckTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(6, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: i < 5 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i <= _currentStep
                        ? RainCheckTheme.primary
                        : RainCheckTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
