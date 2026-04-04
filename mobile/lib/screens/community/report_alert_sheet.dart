import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';

const _kAlertTypes = [
  _AType('Flooding', Icons.flood, Color(0xFF3B82F6)),
  _AType('RoadClosure', Icons.block, Color(0xFFEF4444)),
  _AType('Accident', Icons.car_crash, Color(0xFFF59E0B)),
  _AType('HeavyRain', Icons.water_drop, Color(0xFF0891B2)),
  _AType('Strike', Icons.groups, Color(0xFF8B5CF6)),
  _AType('Other', Icons.warning_amber, Color(0xFF6B7280)),
];

class _AType {
  final String value;
  final IconData icon;
  final Color color;
  const _AType(this.value, this.icon, this.color);
}

class ReportAlertSheet extends ConsumerStatefulWidget {
  const ReportAlertSheet({super.key});

  @override
  ConsumerState<ReportAlertSheet> createState() => _ReportAlertSheetState();
}

class _ReportAlertSheetState extends ConsumerState<ReportAlertSheet> {
  String _selectedType = 'Flooding';
  final _descController = TextEditingController();
  Position? _position;
  double? _accuracy;
  bool _locating = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _locating = false;
          _locationError = 'Location permission denied.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _position = pos;
        _accuracy = pos.accuracy;
        _locating = false;
      });
    } catch (_) {
      setState(() {
        _locating = false;
        _locationError = 'Could not get location.';
      });
    }
  }

  Future<void> _submit() async {
    final st = ref.read(communityProvider);
    if (!st.canSubmit) {
      Toast.error(context, 'Limit reached: ${st.submissionsThisHour}/3 alerts this hour.');
      return;
    }
    if (_position == null) {
      Toast.warning(context, 'Waiting for GPS fix. Please try again.');
      return;
    }
    final riderId = ref.read(authProvider).riderId ?? '';
    final ok = await ref.read(communityProvider.notifier).submitAlert(
          type: _selectedType,
          description: _descController.text.trim(),
          lat: _position!.latitude,
          lng: _position!.longitude,
          locationAccuracy: _accuracy ?? 999,
          riderId: riderId,
        );
    if (!mounted) return;
    final newSt = ref.read(communityProvider);
    if (ok) {
      Navigator.pop(context);
      Toast.success(context, newSt.submitSuccess ?? 'Alert submitted!');
    } else {
      Toast.error(context, newSt.submitError ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(communityProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Report Hazard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _RateLimitBar(used: st.submissionsThisHour, max: 3),
            const SizedBox(height: 16),
            const Text('What type of hazard?',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kAlertTypes
                  .map((t) => _TypeChip(
                        t: t,
                        selected: _selectedType == t.value,
                        onTap: () =>
                            setState(() => _selectedType = t.value),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Additional details (optional)',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'E.g. "Water up to knee, road impassable"',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF1F2937),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                counterStyle:
                    const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            _LocationRow(
              locating: _locating,
              position: _position,
              accuracy: _accuracy,
              error: _locationError,
              onRetry: _fetchLocation,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: st.submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: st.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Alert',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _RateLimitBar extends StatelessWidget {
  final int used;
  final int max;
  const _RateLimitBar({required this.used, required this.max});

  @override
  Widget build(BuildContext context) {
    final remaining = max - used;
    final color = remaining == 0
        ? RainCheckTheme.error
        : remaining == 1
            ? RainCheckTheme.warning
            : RainCheckTheme.success;
    return Row(children: [
      Icon(Icons.timer_outlined, size: 14, color: color),
      const SizedBox(width: 6),
      Text(
          '$remaining alert${remaining == 1 ? '' : 's'} remaining this hour',
          style: TextStyle(color: color, fontSize: 12)),
    ]);
  }
}

class _TypeChip extends StatelessWidget {
  final _AType t;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.t, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? t.color.withAlpha(50)
                : const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? t.color : Colors.transparent, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.icon, color: t.color, size: 18),
            const SizedBox(width: 8),
            Text(t.value,
                style: TextStyle(
                    color:
                        selected ? Colors.white : const Color(0xFF9CA3AF),
                    fontSize: 13)),
          ]),
        ),
      );
}

class _LocationRow extends StatelessWidget {
  final bool locating;
  final Position? position;
  final double? accuracy;
  final String? error;
  final VoidCallback onRetry;
  const _LocationRow(
      {required this.locating,
      required this.position,
      required this.accuracy,
      required this.error,
      required this.onRetry});

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (locating) {
      trailing = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF0D9488)));
    } else if (error != null) {
      trailing = GestureDetector(
        onTap: onRetry,
        child: const Text('Retry',
            style: TextStyle(
                color: RainCheckTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    final poorAccuracy = accuracy != null && accuracy! > 50;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: poorAccuracy
                ? RainCheckTheme.warning.withAlpha(100)
                : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.location_on,
                color: error != null
                    ? RainCheckTheme.error
                    : const Color(0xFF0D9488),
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error ??
                    (locating
                        ? 'Getting location…'
                        : 'Lat: ${position!.latitude.toStringAsFixed(4)}, '
                            'Lng: ${position!.longitude.toStringAsFixed(4)}'),
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
            trailing,
          ]),
          if (poorAccuracy) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.warning_amber,
                  color: RainCheckTheme.warning, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Low GPS accuracy (±${accuracy!.toInt()}m). '
                  'Move outdoors for better precision.',
                  style: const TextStyle(
                      color: RainCheckTheme.warning, fontSize: 11),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
