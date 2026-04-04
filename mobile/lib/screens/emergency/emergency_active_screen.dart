import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../providers/emergency_provider.dart';

class EmergencyActiveScreen extends ConsumerStatefulWidget {
  const EmergencyActiveScreen({super.key});

  @override
  ConsumerState<EmergencyActiveScreen> createState() =>
      _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState
    extends ConsumerState<EmergencyActiveScreen> {
  GoogleMapController? _mapCtrl;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(emergencyProvider);

    // If emergency was cancelled, pop back
    ref.listen(emergencyProvider, (prev, next) {
      if (prev?.isActive == true && !next.isActive) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      // Re-centre map when location updates
      if (next.lat != null &&
          next.lng != null &&
          (prev?.lat != next.lat || prev?.lng != next.lng)) {
        _mapCtrl?.animateCamera(
          CameraUpdate.newLatLng(LatLng(next.lat!, next.lng!)),
        );
      }
    });

    final elapsed = st.activeSince != null
        ? DateTime.now().difference(st.activeSince!)
        : Duration.zero;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0008),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: RainCheckTheme.error.withAlpha(30),
                border: const Border(
                    bottom: BorderSide(
                        color: Color(0x40EF4444), width: 1)),
              ),
              child: Row(children: [
                _PulsingDot(),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Emergency Active',
                      style: TextStyle(
                          color: RainCheckTheme.error,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                _ElapsedTimer(elapsed: elapsed),
              ]),
            ),

            // ── Map ───────────────────────────────────────────────────
            Expanded(
              child: st.lat != null && st.lng != null
                  ? _LiveMap(
                      lat: st.lat!,
                      lng: st.lng!,
                      onMapCreated: (c) => _mapCtrl = c,
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: RainCheckTheme.error),
                          SizedBox(height: 12),
                          Text('Getting your location…',
                              style: TextStyle(
                                  color: RainCheckTheme.textSecondary)),
                        ],
                      ),
                    ),
            ),

            // ── Info panel ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: RainCheckTheme.surface,
                border: Border(
                    top: BorderSide(
                        color: RainCheckTheme.surfaceVariant)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status row
                  Row(children: [
                    const Icon(Icons.people,
                        color: RainCheckTheme.textSecondary, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      st.acknowledgedRiderIds.isEmpty
                          ? 'Notifying nearby riders…'
                          : '${st.acknowledgedRiderIds.length} rider${st.acknowledgedRiderIds.length == 1 ? '' : 's'} acknowledged',
                      style: const TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 13),
                    ),
                    const Spacer(),
                    if (st.lat != null)
                      GestureDetector(
                        onTap: () => _openMaps(st.lat!, st.lng!),
                        child: const Text('Open Maps',
                            style: TextStyle(
                                color: RainCheckTheme.primary,
                                fontSize: 12,
                                decoration: TextDecoration.underline)),
                      ),
                  ]),
                  const SizedBox(height: 16),

                  // Share location button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareLocation(st),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: RainCheckTheme.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share_location,
                          color: RainCheckTheme.primary, size: 18),
                      label: const Text('Share Location',
                          style: TextStyle(
                              color: RainCheckTheme.primary,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // I'm Safe button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmSafe(context, ref),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RainCheckTheme.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle,
                          color: Colors.white, size: 20),
                      label: const Text("I'm Safe",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSafe(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        title: const Text("Confirm you're safe",
            style: TextStyle(color: RainCheckTheme.textPrimary)),
        content: const Text(
            'This will cancel the emergency alert and notify contacts.',
            style: TextStyle(color: RainCheckTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back',
                style: TextStyle(color: RainCheckTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: RainCheckTheme.success),
            child: const Text("I'm Safe",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await ref.read(emergencyProvider.notifier).cancelEmergency();
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _shareLocation(EmergencyState st) {
    if (st.lat == null) return;
    final text =
        '🚨 I need help! My live location: https://maps.google.com/?q=${st.lat},${st.lng}';
    Clipboard.setData(ClipboardData(text: text));
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: RainCheckTheme.error),
        ),
      );
}

class _ElapsedTimer extends StatefulWidget {
  final Duration elapsed;
  const _ElapsedTimer({required this.elapsed});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.elapsed;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _elapsed += const Duration(seconds: 1));
      return true;
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) => Text(
        _fmt(_elapsed),
        style: const TextStyle(
            color: RainCheckTheme.error,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()]),
      );
}

class _LiveMap extends StatelessWidget {
  final double lat;
  final double lng;
  final void Function(GoogleMapController) onMapCreated;
  const _LiveMap(
      {required this.lat, required this.lng, required this.onMapCreated});

  @override
  Widget build(BuildContext context) => GoogleMap(
        onMapCreated: onMapCreated,
        initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng), zoom: 15),
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('emergency'),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Your location'),
          ),
        },
        circles: {
          Circle(
            circleId: const CircleId('radius'),
            center: LatLng(lat, lng),
            radius: 500,
            fillColor: RainCheckTheme.error.withAlpha(15),
            strokeColor: RainCheckTheme.error.withAlpha(60),
            strokeWidth: 1,
          ),
        },
      );
}
