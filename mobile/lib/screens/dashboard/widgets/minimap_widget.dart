import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme.dart';
import '../../../providers/map_provider.dart';

// ── Dark map style JSON ───────────────────────────────────────────────────────

const _darkStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#1a2235"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0a0f1e"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#243047"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#243047"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a0f1e"}]}
]''';

// ── Hue per alert type ────────────────────────────────────────────────────────

double _hue(String type) {
  switch (type) {
    case 'HeavyRain':   return BitmapDescriptor.hueAzure;
    case 'Flooding':    return BitmapDescriptor.hueCyan;
    case 'Accident':    return BitmapDescriptor.hueRed;
    case 'RoadBlock':   return BitmapDescriptor.hueOrange;
    case 'Police':      return BitmapDescriptor.hueYellow;
    default:            return BitmapDescriptor.hueViolet;
  }
}

// ── Widget ────────────────────────────────────────────────────────────────────

class MinimapWidget extends ConsumerStatefulWidget {
  const MinimapWidget({super.key});

  @override
  ConsumerState<MinimapWidget> createState() => _MinimapState();
}

class _MinimapState extends ConsumerState<MinimapWidget> {
  GoogleMapController? _ctrl;
  bool _showAlerts = true;
  bool _showHeatmap = true;

  void _onMapCreated(GoogleMapController c) {
    _ctrl = c;
  }

  void _centreOnRider(double lat, double lng) {
    _ctrl?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 13),
      ),
    );
  }

  // ── Data builders ─────────────────────────────────────────────────────────

  Set<Circle> _circles(MapState s) {
    if (!s.hasLocation) return {};
    return {
      Circle(
        circleId: const CircleId('r10'),
        center: LatLng(s.lat!, s.lng!),
        radius: 10000,
        strokeColor: RainCheckTheme.primary.withAlpha(120),
        strokeWidth: 2,
        fillColor: RainCheckTheme.primary.withAlpha(18),
      ),
    };
  }

  Set<Marker> _markers(MapState s) {
    if (!_showAlerts) return {};
    return s.alerts
        .where((a) => !(a.lat == 0 && a.lng == 0))
        .map((a) => Marker(
              markerId: MarkerId(a.id),
              position: LatLng(a.lat, a.lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                a.verified ? BitmapDescriptor.hueGreen : _hue(a.type),
              ),
              infoWindow: InfoWindow(
                title: a.type.replaceAllMapped(
                  RegExp(r'([A-Z])'),
                  (m) => ' ${m[0]}',
                ).trim(),
                snippet: a.description.isNotEmpty
                    ? a.description
                    : '${a.confirmations} confirmations',
              ),
            ))
        .toSet();
  }

  Set<Polygon> _heatmap(MapState s) {
    if (!_showHeatmap || !s.hasLocation || s.alerts.isEmpty) return {};
    const cellDeg = 0.009; // ~1 km per cell
    final lat0 = s.lat!, lng0 = s.lng!;

    // Bucket alerts into grid cells
    final counts = <String, int>{};
    for (final a in s.alerts) {
      if (a.lat == 0 && a.lng == 0) continue;
      final r = ((a.lat - lat0) / cellDeg).round();
      final c = ((a.lng - lng0) / cellDeg).round();
      final k = '$r,$c';
      counts[k] = (counts[k] ?? 0) + 1;
    }

    final result = <Polygon>{};
    for (final e in counts.entries) {
      final parts = e.key.split(',');
      final cLat = lat0 + int.parse(parts[0]) * cellDeg;
      final cLng = lng0 + int.parse(parts[1]) * cellDeg;

      if (Geolocator.distanceBetween(lat0, lng0, cLat, cLng) > 10500) continue;

      final fill = e.value >= 4
          ? Colors.red.withAlpha(90)
          : e.value >= 2
              ? Colors.orange.withAlpha(75)
              : Colors.yellow.withAlpha(60);

      const h = cellDeg / 2;
      result.add(Polygon(
        polygonId: PolygonId(e.key),
        points: [
          LatLng(cLat - h, cLng - h),
          LatLng(cLat + h, cLng - h),
          LatLng(cLat + h, cLng + h),
          LatLng(cLat - h, cLng + h),
        ],
        fillColor: fill,
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      ));
    }
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(mapProvider);

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RainCheckTheme.surfaceVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          // ── Map / loading / error ─────────────────────────────────────────
          if (s.locating)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: RainCheckTheme.primary),
                  SizedBox(height: 12),
                  Text('Detecting location…',
                      style: TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 13)),
                ],
              ),
            )
          else if (!s.hasLocation)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off,
                        color: RainCheckTheme.textSecondary, size: 40),
                    const SizedBox(height: 12),
                    Text(s.locationError ?? 'Location unavailable',
                        style: const TextStyle(
                            color: RainCheckTheme.textSecondary,
                            fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(mapProvider.notifier).retryLocation(),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: RainCheckTheme.primary),
                      child: const Text('Retry',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              style: _darkStyle,
              initialCameraPosition: CameraPosition(
                target: LatLng(s.lat!, s.lng!),
                zoom: 13,
              ),
              circles: _circles(s),
              markers: _markers(s),
              polygons: _heatmap(s),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),

          // ── Header gradient bar ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RainCheckTheme.surface.withAlpha(230),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(children: [
                const Icon(Icons.radar,
                    color: RainCheckTheme.primary, size: 16),
                const SizedBox(width: 6),
                const Text('10 km Radius',
                    style: TextStyle(
                        color: RainCheckTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (s.loadingAlerts)
                  const SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: RainCheckTheme.primary),
                  )
                else if (s.alerts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: RainCheckTheme.error.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${s.alerts.length} alerts',
                        style: const TextStyle(
                            color: RainCheckTheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                const Spacer(),
                if (s.lastRefresh != null)
                  Text(_ago(s.lastRefresh!),
                      style: TextStyle(
                          color: RainCheckTheme.textSecondary.withAlpha(150),
                          fontSize: 10)),
              ]),
            ),
          ),

          // ── Filter panel ──────────────────────────────────────────────────
          Positioned(
            top: 44, right: 10,
            child: _FilterPanel(
              showAlerts: _showAlerts,
              showHeatmap: _showHeatmap,
              onToggleAlerts: () =>
                  setState(() => _showAlerts = !_showAlerts),
              onToggleHeatmap: () =>
                  setState(() => _showHeatmap = !_showHeatmap),
            ),
          ),

          // ── Bottom-right controls ─────────────────────────────────────────
          Positioned(
            bottom: 12, right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBtn(
                  Icons.refresh,
                  onTap: () => ref.read(mapProvider.notifier).refresh(),
                ),
                const SizedBox(height: 8),
                if (s.hasLocation)
                  _IconBtn(
                    Icons.my_location,
                    onTap: () => _centreOnRider(s.lat!, s.lng!),
                  ),
              ],
            ),
          ),

          // ── Heatmap legend ────────────────────────────────────────────────
          if (_showHeatmap && s.alerts.isNotEmpty)
            Positioned(
              bottom: 12, left: 12,
              child: _HeatmapLegend(),
            ),
        ]),
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final bool showAlerts, showHeatmap;
  final VoidCallback onToggleAlerts, onToggleHeatmap;
  const _FilterPanel({
    required this.showAlerts,
    required this.showHeatmap,
    required this.onToggleAlerts,
    required this.onToggleHeatmap,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface.withAlpha(220),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RainCheckTheme.surfaceVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _FilterChip(
              label: 'Alerts',
              icon: Icons.warning_amber_outlined,
              active: showAlerts,
              onTap: onToggleAlerts),
          const SizedBox(height: 6),
          _FilterChip(
              label: 'Heatmap',
              icon: Icons.grid_view_outlined,
              active: showHeatmap,
              onTap: onToggleHeatmap),
        ]),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:
                active ? RainCheckTheme.primary.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? RainCheckTheme.primary
                  : RainCheckTheme.surfaceVariant,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 12,
                color: active
                    ? RainCheckTheme.primary
                    : RainCheckTheme.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: active
                        ? RainCheckTheme.primary
                        : RainCheckTheme.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, {required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: RainCheckTheme.surface.withAlpha(220),
            shape: BoxShape.circle,
            border: Border.all(color: RainCheckTheme.surfaceVariant),
          ),
          child: Icon(icon, color: RainCheckTheme.primary, size: 18),
        ),
      );
}

class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: RainCheckTheme.surface.withAlpha(220),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: RainCheckTheme.surfaceVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Density ',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 10)),
          _dot(Colors.yellow),
          const SizedBox(width: 3),
          _dot(Colors.orange),
          const SizedBox(width: 3),
          _dot(Colors.red),
        ]),
      );

  Widget _dot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
