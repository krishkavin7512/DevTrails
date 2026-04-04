import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/toast.dart';
import '../../../providers/map_provider.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';

const _alertTypes = [
  _AlertType('HeavyRain', Icons.water_drop, 'Heavy Rain'),
  _AlertType('Flooding', Icons.flood, 'Flooding'),
  _AlertType('Accident', Icons.car_crash, 'Accident'),
  _AlertType('RoadBlock', Icons.block, 'Road Block'),
  _AlertType('Police', Icons.local_police, 'Police Checkpoint'),
  _AlertType('Other', Icons.warning_amber, 'Other'),
];

class _AlertType {
  final String value;
  final IconData icon;
  final String label;
  const _AlertType(this.value, this.icon, this.label);
}

class ReportHazardSheet extends ConsumerStatefulWidget {
  const ReportHazardSheet({super.key});

  @override
  ConsumerState<ReportHazardSheet> createState() => _ReportHazardSheetState();
}

class _ReportHazardSheetState extends ConsumerState<ReportHazardSheet> {
  String _selectedType = 'HeavyRain';
  final _descController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final mapState = ref.read(mapProvider);
    if (!mapState.hasLocation) {
      setState(() => _error = 'Location unavailable. Enable GPS and retry.');
      return;
    }

    final riderId = ref.read(authProvider).riderId;
    if (riderId == null) {
      setState(() => _error = 'Not logged in.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService().submitAlert({
      'riderId': riderId,
      'type': _selectedType,
      'lat': mapState.lat,
      'lng': mapState.lng,
      'description': _descController.text.trim(),
    });

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error ?? 'Failed to submit alert');
      return;
    }

    // Refresh the map to show the new alert
    ref.read(mapProvider.notifier).refresh();
    Navigator.pop(context);
    Toast.success(context, 'Hazard reported. Thank you!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RainCheckTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Report a Hazard',
                  style: TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Help fellow riders stay safe',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Type selector
              const Text('Alert Type',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _alertTypes
                    .map((t) => _TypeChip(
                          type: t,
                          selected: _selectedType == t.value,
                          onTap: () =>
                              setState(() => _selectedType = t.value),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Description
              const Text('Description (optional)',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                style:
                    const TextStyle(color: RainCheckTheme.textPrimary),
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Add more details…',
                  hintStyle: TextStyle(
                      color: RainCheckTheme.textSecondary.withAlpha(120)),
                  filled: true,
                  fillColor: RainCheckTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: RainCheckTheme.surfaceVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: RainCheckTheme.surfaceVariant),
                  ),
                  counterStyle: const TextStyle(
                      color: RainCheckTheme.textSecondary, fontSize: 11),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: RainCheckTheme.error, fontSize: 12)),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RainCheckTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  label: Text(
                    _loading ? 'Submitting…' : 'Submit Report',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final _AlertType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? RainCheckTheme.primary.withAlpha(40)
                : RainCheckTheme.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? RainCheckTheme.primary
                  : RainCheckTheme.surfaceVariant,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(type.icon,
                size: 14,
                color: selected
                    ? RainCheckTheme.primary
                    : RainCheckTheme.textSecondary),
            const SizedBox(width: 5),
            Text(type.label,
                style: TextStyle(
                    color: selected
                        ? RainCheckTheme.primary
                        : RainCheckTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ]),
        ),
      );
}
