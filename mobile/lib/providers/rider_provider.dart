import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/claim.dart';
import '../models/policy.dart';
import '../models/rider.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final _mockRider = Rider(
  id: 'demo',
  fullName: 'Arjun Kumar',
  phone: '9876543210',
  email: 'arjun@example.com',
  city: 'Bangalore',
  platform: 'Swiggy',
  operatingZone: 'Koramangala',
  operatingPincode: '560034',
  avgWeeklyEarnings: 350000,
  avgDailyHours: 8,
  preferredShift: 'Evening',
  vehicleType: 'Scooter',
  experienceMonths: 18,
  riskTier: 'Medium',
  riskScore: 45,
  isActive: true,
  kycVerified: true,
  location: const RiderLocation(lat: 12.9352, lng: 77.6245),
  registeredAt: DateTime(2023, 9, 1),
  lastActiveAt: DateTime.now(),
  createdAt: DateTime(2023, 9, 1),
  updatedAt: DateTime.now(),
);

final _mockPolicy = Policy(
  id: 'demo',
  riderId: 'demo',
  planType: 'Premium',
  weeklyPremium: 4900,
  coverageLimit: 150000,
  coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'],
  status: 'Active',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2025, 1, 1),
  autoRenew: true,
  policyNumber: 'RC-20240001',
  renewalCount: 2,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime.now(),
);

final _mockClaims = [
  Claim(
    id: '1',
    policyId: 'demo',
    riderId: 'demo',
    claimNumber: 'CLM-20240301-00001',
    triggerType: 'HeavyRain',
    triggerData: TriggerData(
      parameter: 'rainfall_mm',
      threshold: 50,
      actualValue: 78.4,
      dataSource: 'OpenWeatherMap',
      timestamp: DateTime(2024, 3, 1, 14, 30),
      lat: 12.9352,
      lng: 77.6245,
    ),
    estimatedLostHours: 3.5,
    payoutAmount: 35000,
    status: 'Paid',
    fraudScore: 12,
    fraudFlags: [],
    paidAt: DateTime(2024, 3, 1, 16, 0),
    createdAt: DateTime(2024, 3, 1),
    updatedAt: DateTime(2024, 3, 1),
  ),
  Claim(
    id: '2',
    policyId: 'demo',
    riderId: 'demo',
    claimNumber: 'CLM-20240228-00003',
    triggerType: 'SevereAQI',
    triggerData: TriggerData(
      parameter: 'aqi',
      threshold: 200,
      actualValue: 267,
      dataSource: 'CPCB',
      timestamp: DateTime(2024, 2, 28, 11, 0),
      lat: 12.9352,
      lng: 77.6245,
    ),
    estimatedLostHours: 2.5,
    payoutAmount: 28000,
    status: 'AutoInitiated',
    fraudScore: 8,
    fraudFlags: [],
    createdAt: DateTime(2024, 2, 28),
    updatedAt: DateTime(2024, 2, 28),
  ),
];

bool _isObjectId(String? id) =>
    id != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(id);

class RiderDashboardData {
  final Rider rider;
  final Policy? policy;
  final List<Claim> recentClaims;
  const RiderDashboardData({
    required this.rider,
    required this.policy,
    required this.recentClaims,
  });
}

final riderDashboardProvider =
    FutureProvider<RiderDashboardData>((ref) async {
  final riderId = ref.watch(riderIdProvider);

  if (!_isObjectId(riderId)) {
    await Future.delayed(const Duration(milliseconds: 500));
    return RiderDashboardData(
      rider: _mockRider,
      policy: _mockPolicy,
      recentClaims: _mockClaims,
    );
  }

  try {
    final api = ApiService();
    final dashRes = await api.getRiderDashboard(riderId!);
    final claimsRes = await api.getRiderClaims(riderId, limit: 5);

    if (!dashRes.success || dashRes.data == null) {
      throw Exception(dashRes.error);
    }

    final dashData = dashRes.data!;

    return RiderDashboardData(
      rider: Rider.fromJson(dashData['rider'] as Map<String, dynamic>),
      policy: dashData['activePolicy'] != null
          ? Policy.fromJson(
              dashData['activePolicy'] as Map<String, dynamic>)
          : null,
      recentClaims: claimsRes.data ?? [],
    );
  } catch (_) {
    return RiderDashboardData(
      rider: _mockRider,
      policy: _mockPolicy,
      recentClaims: _mockClaims,
    );
  }
});
