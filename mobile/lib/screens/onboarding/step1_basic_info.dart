import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/onboarding_provider.dart';
import 'onboarding_widgets.dart';

const _cities = [
  'Bangalore', 'Mumbai', 'Delhi', 'Hyderabad', 'Chennai',
  'Pune', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Lucknow',
];

class Step1BasicInfo extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const Step1BasicInfo({super.key, required this.onNext});

  @override
  ConsumerState<Step1BasicInfo> createState() => _Step1State();
}

class _Step1State extends ConsumerState<Step1BasicInfo> {
  final _nameCtrl = TextEditingController();
  String _city = _cities[0];
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingProvider);
    _nameCtrl.text = d.fullName;
    if (_cities.contains(d.city)) _city = d.city;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    ref.read(onboardingProvider.notifier).updateBasicInfo(
          fullName: _nameCtrl.text.trim(),
          city: _city,
          platform: ref.read(onboardingProvider).platform,
        );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tell us about yourself',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Basic details to personalise your coverage',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),

          const OLabel('Full Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. Arjun Kumar',
              prefixIcon: Icon(Icons.person_outline,
                  color: RainCheckTheme.textSecondary),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: const TextStyle(
                    color: RainCheckTheme.error, fontSize: 12)),
          ],
          const SizedBox(height: 24),

          const OLabel('Your City'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_city),
            initialValue: _city,
            dropdownColor: RainCheckTheme.surface,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_city_outlined,
                  color: RainCheckTheme.textSecondary),
            ),
            items: _cities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _city = v!),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 36),
          OnboardingButton(label: 'Continue', onTap: _submit),
        ],
      ),
    );
  }
}
