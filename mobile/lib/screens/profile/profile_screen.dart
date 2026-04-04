import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_transitions.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../models/rider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../payment/subscription_screen.dart';
import 'notification_settings_screen.dart';
import 'policy_management_screen.dart';

// ── Local settings keys ───────────────────────────────────────────────────────
const _kUpiKey       = 'profile_upi_id';
const _kEcNameKey    = 'profile_ec_name';
const _kEcPhoneKey   = 'profile_ec_phone';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderDashboardProvider);
    return Scaffold(
      backgroundColor: RainCheckTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(riderDashboardProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: RainCheckTheme.primary)),
        error: (_, __) => const SizedBox(),
        data: (data) => _ProfileBody(rider: data.rider),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final Rider rider;
  const _ProfileBody({required this.rider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider.notifier).isDark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Avatar + name ─────────────────────────────────────────────
        _AvatarHeader(rider: rider),
        const SizedBox(height: 20),

        // ── Trust score ───────────────────────────────────────────────
        _TrustScoreCard(rider: rider),
        const SizedBox(height: 16),

        // ── Rider details ─────────────────────────────────────────────
        _SectionCard(
          title: 'Rider Details',
          trailing: TextButton.icon(
            onPressed: () => _openEditSheet(context, ref, rider),
            icon: const Icon(Icons.edit_outlined,
                size: 14, color: RainCheckTheme.primary),
            label: const Text('Edit',
                style: TextStyle(
                    color: RainCheckTheme.primary, fontSize: 13)),
          ),
          child: Column(
            children: [
              _InfoRow('City', rider.city),
              _InfoRow('Zone', rider.operatingZone),
              _InfoRow('Pincode', rider.operatingPincode),
              _InfoRow('Platform', rider.platform),
              _InfoRow('Vehicle', rider.vehicleType),
              _InfoRow('Experience', '${rider.experienceMonths} months'),
              _InfoRow(
                  'Earnings/week', rider.weeklyEarningsFormatted),
              _InfoRow('Shift', rider.preferredShift),
              _InfoRow('KYC', rider.kycVerified ? 'Verified ✓' : 'Pending'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── UPI ID ────────────────────────────────────────────────────
        const _UpiSection(),
        const SizedBox(height: 16),

        // ── Emergency contact ─────────────────────────────────────────
        const _EmergencyContactSection(),
        const SizedBox(height: 16),

        // ── Settings & navigation ─────────────────────────────────────
        _SectionCard(
          title: 'Settings',
          child: Column(
            children: [
              _NavTile(
                icon: Icons.shield_outlined,
                label: 'My Policy',
                onTap: () => Navigator.push(
                  context,
                  SlideRightRoute(page: const PolicyManagementScreen()),
                ),
              ),
              _NavTile(
                icon: Icons.credit_card_outlined,
                label: 'Subscription & Payments',
                onTap: () => Navigator.push(
                  context,
                  SlideRightRoute(page: const SubscriptionScreen()),
                ),
              ),
              _NavTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => Navigator.push(
                  context,
                  SlideRightRoute(page: const NotificationSettingsScreen()),
                ),
              ),
              // Dark mode toggle
              _ToggleTile(
                icon: isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                label: 'Dark Mode',
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Sign out ──────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout,
                color: RainCheckTheme.error, size: 18),
            label: const Text('Sign Out',
                style: TextStyle(
                    color: RainCheckTheme.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: RainCheckTheme.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _openEditSheet(
      BuildContext context, WidgetRef ref, Rider rider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RainCheckTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(rider: rider, ref: ref),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RainCheckTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out?',
            style: TextStyle(color: RainCheckTheme.textPrimary)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(
              color: RainCheckTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style:
                    TextStyle(color: RainCheckTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Sign Out',
                style: TextStyle(color: RainCheckTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ── Avatar header ─────────────────────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  final Rider rider;
  const _AvatarHeader({required this.rider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: RainCheckTheme.primary.withAlpha(38),
              child: Text(
                rider.initials,
                style: const TextStyle(
                    color: RainCheckTheme.primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700),
              ),
            ),
            if (rider.kycVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: RainCheckTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: RainCheckTheme.background, width: 2),
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(rider.fullName,
            style: const TextStyle(
                color: RainCheckTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(rider.phone,
            style: const TextStyle(
                color: RainCheckTheme.textSecondary, fontSize: 14)),
        if (rider.email != null) ...[
          const SizedBox(height: 2),
          Text(rider.email!,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13)),
        ],
      ],
    );
  }
}

// ── Trust score card ──────────────────────────────────────────────────────────

class _TrustScoreCard extends StatelessWidget {
  final Rider rider;
  const _TrustScoreCard({required this.rider});

  // Trust score = inverse of risk score
  double get _trustScore => (100 - rider.riskScore).clamp(0, 100);

  Color get _trustColor {
    if (_trustScore >= 75) return RainCheckTheme.success;
    if (_trustScore >= 50) return RainCheckTheme.primary;
    if (_trustScore >= 30) return RainCheckTheme.warning;
    return RainCheckTheme.error;
  }

  String get _trustLabel {
    if (_trustScore >= 75) return 'Excellent';
    if (_trustScore >= 50) return 'Good';
    if (_trustScore >= 30) return 'Fair';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RainCheckTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _trustColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Trust Score',
                  style: TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _trustColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_trustLabel,
                    style: TextStyle(
                        color: _trustColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _trustScore.toStringAsFixed(0),
                style: TextStyle(
                    color: _trustColor,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/100',
                    style: TextStyle(
                        color: _trustColor.withAlpha(140),
                        fontSize: 16)),
              ),
              const Spacer(),
              // Risk tier badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Risk Tier',
                      style: TextStyle(
                          color: RainCheckTheme.textSecondary,
                          fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(rider.riskTier,
                      style: TextStyle(
                          color: _riskTierColor(rider.riskTier),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _trustScore / 100,
              backgroundColor: RainCheckTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(_trustColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          // Breakdown chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _BreakdownChip(
                  label: 'KYC',
                  ok: rider.kycVerified),
              _BreakdownChip(
                  label: 'Experience',
                  ok: rider.experienceMonths >= 6),
              _BreakdownChip(
                  label: 'Activity',
                  ok: rider.isActive),
              _BreakdownChip(
                  label: 'Claim History',
                  ok: rider.riskScore < 60),
            ],
          ),
        ],
      ),
    );
  }

  Color _riskTierColor(String tier) => switch (tier) {
        'Low'      => RainCheckTheme.success,
        'Medium'   => RainCheckTheme.primary,
        'High'     => RainCheckTheme.warning,
        'VeryHigh' => RainCheckTheme.error,
        _          => RainCheckTheme.textSecondary,
      };
}

class _BreakdownChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _BreakdownChip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? RainCheckTheme.success : RainCheckTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.radio_button_unchecked,
              size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── UPI section ───────────────────────────────────────────────────────────────

class _UpiSection extends StatefulWidget {
  const _UpiSection();

  @override
  State<_UpiSection> createState() => _UpiSectionState();
}

class _UpiSectionState extends State<_UpiSection> {
  String _upiId = '';
  bool _editing = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kUpiKey) ?? '';
    if (mounted) setState(() => _upiId = val);
  }

  Future<void> _save() async {
    final val = _ctrl.text.trim();
    // Basic UPI format: word@word
    if (val.isNotEmpty &&
        !RegExp(r'^[\w.\-+]+@[\w]+$').hasMatch(val)) {
      Toast.error(context, 'Enter a valid UPI ID (e.g. name@upi)');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUpiKey, val);
    setState(() { _upiId = val; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'UPI ID',
      trailing: _editing
          ? null
          : TextButton.icon(
              onPressed: () {
                _ctrl.text = _upiId;
                setState(() => _editing = true);
              },
              icon: const Icon(Icons.edit_outlined,
                  size: 14, color: RainCheckTheme.primary),
              label: const Text('Edit',
                  style: TextStyle(
                      color: RainCheckTheme.primary, fontSize: 13)),
            ),
      child: _editing
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: const TextStyle(
                        color: RainCheckTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'yourname@upi',
                      hintStyle: TextStyle(
                          color: RainCheckTheme.textSecondary),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                TextButton(
                    onPressed: _save,
                    child: const Text('Save',
                        style: TextStyle(
                            color: RainCheckTheme.success))),
                TextButton(
                    onPressed: () =>
                        setState(() => _editing = false),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: RainCheckTheme.textSecondary))),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: RainCheckTheme.textSecondary, size: 18),
                const SizedBox(width: 10),
                Text(
                  _upiId.isEmpty ? 'Not set' : _upiId,
                  style: TextStyle(
                      color: _upiId.isEmpty
                          ? RainCheckTheme.textSecondary
                          : RainCheckTheme.textPrimary,
                      fontSize: 14,
                      fontStyle: _upiId.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal),
                ),
              ],
            ),
    );
  }
}

// ── Emergency contact section ─────────────────────────────────────────────────

class _EmergencyContactSection extends StatefulWidget {
  const _EmergencyContactSection();

  @override
  State<_EmergencyContactSection> createState() =>
      _EmergencyContactSectionState();
}

class _EmergencyContactSectionState
    extends State<_EmergencyContactSection> {
  String _name = '';
  String _phone = '';
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController();
    _phoneCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name  = prefs.getString(_kEcNameKey)  ?? '';
    final phone = prefs.getString(_kEcPhoneKey) ?? '';
    if (mounted) setState(() { _name = name; _phone = phone; });
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty &&
        !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      Toast.error(context, 'Enter a valid 10-digit Indian mobile number');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEcNameKey, name);
    await prefs.setString(_kEcPhoneKey, phone);
    setState(() { _name = name; _phone = phone; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Emergency Contact',
      trailing: _editing
          ? null
          : TextButton.icon(
              onPressed: () {
                _nameCtrl.text  = _name;
                _phoneCtrl.text = _phone;
                setState(() => _editing = true);
              },
              icon: const Icon(Icons.edit_outlined,
                  size: 14, color: RainCheckTheme.primary),
              label: const Text('Edit',
                  style: TextStyle(
                      color: RainCheckTheme.primary, fontSize: 13)),
            ),
      child: _editing
          ? Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: const TextStyle(
                      color: RainCheckTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(
                        color: RainCheckTheme.textSecondary),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                      color: RainCheckTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    labelStyle: TextStyle(
                        color: RainCheckTheme.textSecondary),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () =>
                            setState(() => _editing = false),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: RainCheckTheme.textSecondary))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: RainCheckTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8)),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.emergency_outlined,
                    color: RainCheckTheme.error, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: _name.isEmpty && _phone.isEmpty
                      ? const Text('Not set',
                          style: TextStyle(
                              color: RainCheckTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 14))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_name.isNotEmpty)
                              Text(_name,
                                  style: const TextStyle(
                                      color: RainCheckTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            if (_phone.isNotEmpty)
                              Text(_phone,
                                  style: const TextStyle(
                                      color: RainCheckTheme.textSecondary,
                                      fontSize: 13)),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final Rider rider;
  final WidgetRef ref;
  const _EditProfileSheet({required this.rider, required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _zoneCtrl;
  late String _city;
  late String _platform;
  late String _vehicle;
  late String _shift;
  bool _saving = false;
  String? _error;

  static const _cities = [
    'Bangalore', 'Mumbai', 'Delhi', 'Hyderabad', 'Chennai',
    'Pune', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Lucknow',
  ];
  static const _platforms = ['Zomato', 'Swiggy', 'Both'];
  static const _vehicles  = ['Bicycle', 'Scooter', 'Motorcycle'];
  static const _shifts    = ['Morning', 'Afternoon', 'Evening', 'Night', 'Mixed'];

  @override
  void initState() {
    super.initState();
    final r = widget.rider;
    _nameCtrl  = TextEditingController(text: r.fullName);
    _emailCtrl = TextEditingController(text: r.email ?? '');
    _zoneCtrl  = TextEditingController(text: r.operatingZone);
    _city      = _cities.contains(r.city) ? r.city : _cities.first;
    _platform  = r.platform;
    _vehicle   = r.vehicleType;
    _shift     = r.preferredShift;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = 'Name must be at least 2 characters.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final res = await ApiService().updateRider(widget.rider.id, {
      'fullName':      _nameCtrl.text.trim(),
      'email':         _emailCtrl.text.trim().isEmpty
          ? null
          : _emailCtrl.text.trim(),
      'city':          _city,
      'operatingZone': _zoneCtrl.text.trim(),
      'platform':      _platform,
      'vehicleType':   _vehicle,
      'preferredShift': _shift,
    });

    setState(() => _saving = false);
    if (!mounted) return;

    if (res.success) {
      widget.ref.invalidate(riderDashboardProvider);
      Navigator.pop(context);
      Toast.success(context, 'Profile updated');
    } else {
      setState(() => _error = res.error ?? 'Update failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: RainCheckTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Edit Profile',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _SheetField(ctrl: _nameCtrl, label: 'Full Name'),
          const SizedBox(height: 12),
          _SheetField(
              ctrl: _emailCtrl,
              label: 'Email (optional)',
              type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _SheetField(ctrl: _zoneCtrl, label: 'Operating Zone'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _SheetDropdown(
                      label: 'City',
                      value: _city,
                      items: _cities,
                      onChanged: (v) => setState(() => _city = v))),
              const SizedBox(width: 10),
              Expanded(
                  child: _SheetDropdown(
                      label: 'Platform',
                      value: _platform,
                      items: _platforms,
                      onChanged: (v) => setState(() => _platform = v))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _SheetDropdown(
                      label: 'Vehicle',
                      value: _vehicle,
                      items: _vehicles,
                      onChanged: (v) => setState(() => _vehicle = v))),
              const SizedBox(width: 10),
              Expanded(
                  child: _SheetDropdown(
                      label: 'Shift',
                      value: _shift,
                      items: _shifts,
                      onChanged: (v) => setState(() => _shift = v))),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: RainCheckTheme.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: RainCheckTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
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

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  const _SheetField(
      {required this.ctrl,
      required this.label,
      this.type = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: RainCheckTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: RainCheckTheme.textSecondary),
        filled: true,
        fillColor: RainCheckTheme.surfaceVariant,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _SheetDropdown(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: RainCheckTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: RainCheckTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: RainCheckTheme.surface,
              style: const TextStyle(
                  color: RainCheckTheme.textPrimary, fontSize: 13),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: RainCheckTheme.textSecondary, size: 18),
              items: items
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared section card & tiles ───────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard(
      {required this.title, required this.child, this.trailing});

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
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: RainCheckTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: RainCheckTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: RainCheckTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right,
                color: RainCheckTheme.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: RainCheckTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: RainCheckTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: RainCheckTheme.primary,
            activeTrackColor: RainCheckTheme.primary.withAlpha(80),
          ),
        ],
      ),
    );
  }
}
