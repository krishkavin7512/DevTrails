import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_transitions.dart';
import '../core/theme.dart';
import '../providers/connectivity_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/forecast_provider.dart';
import 'alerts/predictive_alerts_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'dashboard/widgets/report_hazard_sheet.dart';
import 'claims/claims_list_screen.dart';
import 'community/alerts_screen.dart';
import 'emergency/panic_button_screen.dart';
import 'profile/profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    DashboardScreen(),
    ClaimsListScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Sensor monitoring starts inside EmergencyNotifier constructor;
    // we just listen for crash events here to show the overlay dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForCrash();
    });
  }

  void _listenForCrash() {
    ref.listenManual(emergencyProvider, (prev, next) {
      if (next.phase == EmergencyPhase.crashDetected &&
          prev?.phase != EmergencyPhase.crashDetected &&
          mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const CrashDetectionOverlay(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(
        forecastProvider.select((s) => s.activeCount));
    final isOnline = ref.watch(connectivityProvider);

    return Scaffold(
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ReportHazardSheet(),
              ),
              backgroundColor: RainCheckTheme.primary,
              icon: const Icon(Icons.add_location_alt, color: Colors.white),
              label: const Text('Report Hazard',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Stack(
        children: [
          _tabs[_currentIndex],
          // ── Offline banner ────────────────────────────────────────
          if (!isOnline)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: const _OfflineBanner(),
            ),
          // ── Persistent weather-alert bell (top-right) ─────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _AlertBell(
              count: alertCount,
              onTap: () => Navigator.push(
                context,
                SlideUpRoute(page: const PredictiveAlertsScreen()),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SOS strip above nav bar
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlideUpRoute(page: const PanicButtonScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: RainCheckTheme.error.withAlpha(20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos, color: RainCheckTheme.error, size: 16),
                  SizedBox(width: 6),
                  Text('SOS Emergency',
                      style: TextStyle(
                          color: RainCheckTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: RainCheckTheme.surfaceVariant, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Claims',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Community',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: RainCheckTheme.warning,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('You are offline — showing cached data',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Weather alert bell with badge ─────────────────────────────────────────────

class _AlertBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _AlertBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: RainCheckTheme.surface.withAlpha(220),
          shape: BoxShape.circle,
          border: Border.all(color: RainCheckTheme.surfaceVariant),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.notifications_outlined,
                  color: RainCheckTheme.textPrimary, size: 20),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: RainCheckTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
