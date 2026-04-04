import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme.dart';
import '../../providers/onboarding_provider.dart';
import 'onboarding_widgets.dart';

const _cityZones = <String, List<String>>{
  'Bangalore': [
    'Central', 'North Bangalore', 'South Bangalore',
    'East Bangalore', 'Whitefield', 'Electronic City', 'HSR Layout',
  ],
  'Mumbai': [
    'South Mumbai', 'Central Mumbai', 'Western Suburbs',
    'Eastern Suburbs', 'Navi Mumbai', 'Thane',
  ],
  'Delhi': [
    'Central Delhi', 'North Delhi', 'South Delhi',
    'East Delhi', 'West Delhi', 'Noida', 'Gurgaon',
  ],
  'Hyderabad': [
    'Hyderabad Central', 'Secunderabad', 'HITEC City',
    'Gachibowli', 'Kukatpally', 'LB Nagar',
  ],
  'Chennai': [
    'Central Chennai', 'North Chennai', 'South Chennai',
    'West Chennai', 'Anna Nagar', 'OMR',
  ],
  'Pune': [
    'Central Pune', 'Shivajinagar', 'Hinjewadi',
    'Kothrud', 'Viman Nagar', 'Hadapsar',
  ],
  'Kolkata': [
    'Central Kolkata', 'North Kolkata', 'South Kolkata',
    'Howrah', 'Salt Lake', 'New Town',
  ],
  'Ahmedabad': [
    'Central', 'SG Highway', 'Satellite', 'Maninagar', 'Bopal', 'Navrangpura',
  ],
  'Jaipur': [
    'Pink City', 'Vaishali Nagar', 'Mansarovar',
    'Malviya Nagar', 'Tonk Road', 'Ajmer Road',
  ],
  'Lucknow': [
    'Hazratganj', 'Gomti Nagar', 'Aliganj',
    'Chowk', 'Alambagh', 'Indira Nagar',
  ],
};

class Step2Location extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step2Location(
      {super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<Step2Location> createState() => _Step2State();
}

class _Step2State extends ConsumerState<Step2Location> {
  bool _detecting = false;
  String? _error;
  double? _lat;
  double? _lng;
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _zone = '';
  GoogleMapController? _mapCtrl;

  List<String> get _zones {
    final city = ref.read(onboardingProvider).city;
    return _cityZones[city] ??
        ['Central', 'North', 'South', 'East', 'West'];
  }

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingProvider);
    if (d.lat != null) {
      _lat = d.lat;
      _lng = d.lng;
      _addressCtrl.text = d.address;
      _pincodeCtrl.text = d.operatingPincode;
    }
    final savedZone = d.operatingZone;
    _zone = savedZone.isNotEmpty ? savedZone : _zones.first;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _detecting = true;
      _error = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(
            () => _error = 'Location permission denied. Enter address manually.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lat = pos.latitude;
      _lng = pos.longitude;

      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final p = marks.first;
          final parts = [p.street, p.subLocality, p.locality]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
          _addressCtrl.text = parts;
          _pincodeCtrl.text = p.postalCode ?? '';

          final locality =
              (p.subLocality ?? p.locality ?? '').toLowerCase();
          final autoZone = _zones.firstWhere(
            (z) =>
                locality.contains(z.toLowerCase().split(' ').first),
            orElse: () => _zones.first,
          );
          setState(() => _zone = autoZone);
        }
      } catch (_) {
        _addressCtrl.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }

      _mapCtrl?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_lat!, _lng!)));
      setState(() {});
    } catch (e) {
      setState(() => _error = 'Could not get location. Try again.');
    } finally {
      setState(() => _detecting = false);
    }
  }

  void _submit() {
    if (_lat == null && _addressCtrl.text.trim().isNotEmpty) {
      // Use Mumbai default coords if address entered but GPS not available
      _lat = 19.0760;
      _lng = 72.8777;
    }
    if (_lat == null) {
      setState(
          () => _error = 'Tap "Detect My Location" or enter your address');
      return;
    }
    if (_pincodeCtrl.text.trim().length < 6) {
      setState(() => _error = 'Enter a valid 6-digit pincode');
      return;
    }
    ref.read(onboardingProvider.notifier).updateLocation(
          lat: _lat!,
          lng: _lng!,
          address: _addressCtrl.text.trim(),
          operatingZone: _zone,
          operatingPincode: _pincodeCtrl.text.trim(),
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
          const Text('Your operating area',
              style: TextStyle(
                  color: RainCheckTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Used to assess localised weather & AQI risk',
              style: TextStyle(
                  color: RainCheckTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // GPS detect button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _detecting ? null : _detectLocation,
              icon: _detecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RainCheckTheme.primary))
                  : const Icon(Icons.my_location,
                      color: RainCheckTheme.primary),
              label: Text(
                _detecting ? 'Detecting…' : 'Detect My Location',
                style: const TextStyle(
                    color: RainCheckTheme.primary,
                    fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: RainCheckTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_error != null) ErrorBanner(_error!),

          // Map preview
          if (_lat != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                child: GoogleMap(
                  onMapCreated: (c) => _mapCtrl = c,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_lat!, _lng!),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('rider'),
                      position: LatLng(_lat!, _lng!),
                    )
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          const OLabel('Address / Landmark'),
          const SizedBox(height: 8),
          TextField(
            controller: _addressCtrl,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Street, area, landmark…',
              prefixIcon: Icon(Icons.home_outlined,
                  color: RainCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),

          const OLabel('Operating Zone'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_zone),
            initialValue: _zone.isNotEmpty ? _zone : null,
            dropdownColor: RainCheckTheme.surface,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.map_outlined,
                  color: RainCheckTheme.textSecondary),
            ),
            items: _zones
                .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                .toList(),
            onChanged: (v) => setState(() => _zone = v!),
          ),
          const SizedBox(height: 16),

          const OLabel('Pincode'),
          const SizedBox(height: 8),
          TextField(
            controller: _pincodeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: RainCheckTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: '560034',
              counterText: '',
              prefixIcon: Icon(Icons.pin_drop_outlined,
                  color: RainCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 32),

          NavRow(onBack: widget.onBack, onNext: _submit),
        ],
      ),
    );
  }
}
