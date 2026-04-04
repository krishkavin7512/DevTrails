import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingData {
  // Step 1 — Basic Info
  final String fullName;
  final String city;
  final String platform;
  // Step 2 — Location
  final double? lat;
  final double? lng;
  final String address;
  final String operatingZone;
  final String operatingPincode;
  // Step 3 — Work Profile
  final int weeklyEarningsPaise; // e.g. 400000 = ₹4 000
  final int dailyHours;
  final int experienceMonths;
  final String vehicleType;
  final String preferredShift;
  // Step 4 — ML result
  final double? riskScore;
  final String? riskTier;
  final List<String> riskFactors;
  final int? recommendedPremiumPaise;
  // Step 5 — Selected plan
  final String? selectedPlan;
  final int? weeklyPremium;
  final int? coverageLimit;
  final List<String> coveredDisruptions;
  // Internal
  final bool paymentComplete;

  const OnboardingData({
    this.fullName = '',
    this.city = '',
    this.platform = 'Zomato',
    this.lat,
    this.lng,
    this.address = '',
    this.operatingZone = '',
    this.operatingPincode = '',
    this.weeklyEarningsPaise = 400000,
    this.dailyHours = 8,
    this.experienceMonths = 12,
    this.vehicleType = 'Scooter',
    this.preferredShift = 'Mixed',
    this.riskScore,
    this.riskTier,
    this.riskFactors = const [],
    this.recommendedPremiumPaise,
    this.selectedPlan,
    this.weeklyPremium,
    this.coverageLimit,
    this.coveredDisruptions = const [],
    this.paymentComplete = false,
  });

  OnboardingData copyWith({
    String? fullName,
    String? city,
    String? platform,
    double? lat,
    double? lng,
    String? address,
    String? operatingZone,
    String? operatingPincode,
    int? weeklyEarningsPaise,
    int? dailyHours,
    int? experienceMonths,
    String? vehicleType,
    String? preferredShift,
    double? riskScore,
    String? riskTier,
    List<String>? riskFactors,
    int? recommendedPremiumPaise,
    String? selectedPlan,
    int? weeklyPremium,
    int? coverageLimit,
    List<String>? coveredDisruptions,
    bool? paymentComplete,
  }) =>
      OnboardingData(
        fullName: fullName ?? this.fullName,
        city: city ?? this.city,
        platform: platform ?? this.platform,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        address: address ?? this.address,
        operatingZone: operatingZone ?? this.operatingZone,
        operatingPincode: operatingPincode ?? this.operatingPincode,
        weeklyEarningsPaise: weeklyEarningsPaise ?? this.weeklyEarningsPaise,
        dailyHours: dailyHours ?? this.dailyHours,
        experienceMonths: experienceMonths ?? this.experienceMonths,
        vehicleType: vehicleType ?? this.vehicleType,
        preferredShift: preferredShift ?? this.preferredShift,
        riskScore: riskScore ?? this.riskScore,
        riskTier: riskTier ?? this.riskTier,
        riskFactors: riskFactors ?? this.riskFactors,
        recommendedPremiumPaise:
            recommendedPremiumPaise ?? this.recommendedPremiumPaise,
        selectedPlan: selectedPlan ?? this.selectedPlan,
        weeklyPremium: weeklyPremium ?? this.weeklyPremium,
        coverageLimit: coverageLimit ?? this.coverageLimit,
        coveredDisruptions: coveredDisruptions ?? this.coveredDisruptions,
        paymentComplete: paymentComplete ?? this.paymentComplete,
      );

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'city': city,
        'platform': platform,
        'lat': lat,
        'lng': lng,
        'address': address,
        'operatingZone': operatingZone,
        'operatingPincode': operatingPincode,
        'weeklyEarningsPaise': weeklyEarningsPaise,
        'dailyHours': dailyHours,
        'experienceMonths': experienceMonths,
        'vehicleType': vehicleType,
        'preferredShift': preferredShift,
        'riskScore': riskScore,
        'riskTier': riskTier,
        'riskFactors': riskFactors,
        'recommendedPremiumPaise': recommendedPremiumPaise,
        'selectedPlan': selectedPlan,
        'weeklyPremium': weeklyPremium,
        'coverageLimit': coverageLimit,
        'coveredDisruptions': coveredDisruptions,
        'paymentComplete': paymentComplete,
      };

  factory OnboardingData.fromJson(Map<String, dynamic> j) => OnboardingData(
        fullName: j['fullName'] ?? '',
        city: j['city'] ?? '',
        platform: j['platform'] ?? 'Zomato',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        address: j['address'] ?? '',
        operatingZone: j['operatingZone'] ?? '',
        operatingPincode: j['operatingPincode'] ?? '',
        weeklyEarningsPaise: j['weeklyEarningsPaise'] ?? 400000,
        dailyHours: j['dailyHours'] ?? 8,
        experienceMonths: j['experienceMonths'] ?? 12,
        vehicleType: j['vehicleType'] ?? 'Scooter',
        preferredShift: j['preferredShift'] ?? 'Mixed',
        riskScore: (j['riskScore'] as num?)?.toDouble(),
        riskTier: j['riskTier'],
        riskFactors: List<String>.from(j['riskFactors'] ?? []),
        recommendedPremiumPaise: j['recommendedPremiumPaise'],
        selectedPlan: j['selectedPlan'],
        weeklyPremium: j['weeklyPremium'],
        coverageLimit: j['coverageLimit'],
        coveredDisruptions: List<String>.from(j['coveredDisruptions'] ?? []),
        paymentComplete: j['paymentComplete'] ?? false,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class OnboardingNotifier extends StateNotifier<OnboardingData> {
  static const _key = 'onboarding_progress';

  OnboardingNotifier() : super(const OnboardingData()) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = OnboardingData.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  Future<void> clearSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  // Called from register_screen after rider creation
  void initFromRegistration({
    required String fullName,
    required String city,
    required String platform,
    required String vehicleType,
  }) {
    state = state.copyWith(
      fullName: fullName,
      city: city,
      platform: platform,
      vehicleType: vehicleType,
    );
  }

  void updateBasicInfo({
    required String fullName,
    required String city,
    required String platform,
  }) {
    state = state.copyWith(
        fullName: fullName, city: city, platform: platform);
    _persist();
  }

  void updateLocation({
    required double lat,
    required double lng,
    required String address,
    required String operatingZone,
    required String operatingPincode,
  }) {
    state = state.copyWith(
      lat: lat,
      lng: lng,
      address: address,
      operatingZone: operatingZone,
      operatingPincode: operatingPincode,
    );
    _persist();
  }

  void updateWorkProfile({
    required int weeklyEarningsPaise,
    required int dailyHours,
    required int experienceMonths,
    required String vehicleType,
    required String preferredShift,
  }) {
    state = state.copyWith(
      weeklyEarningsPaise: weeklyEarningsPaise,
      dailyHours: dailyHours,
      experienceMonths: experienceMonths,
      vehicleType: vehicleType,
      preferredShift: preferredShift,
    );
    _persist();
  }

  void setRiskResult({
    required double riskScore,
    required String riskTier,
    required List<String> riskFactors,
    int? recommendedPremiumPaise,
  }) {
    state = state.copyWith(
      riskScore: riskScore,
      riskTier: riskTier,
      riskFactors: riskFactors,
      recommendedPremiumPaise: recommendedPremiumPaise,
    );
    _persist();
  }

  void selectPlan({
    required String plan,
    required int weeklyPremium,
    required int coverageLimit,
    required List<String> coveredDisruptions,
  }) {
    state = state.copyWith(
      selectedPlan: plan,
      weeklyPremium: weeklyPremium,
      coverageLimit: coverageLimit,
      coveredDisruptions: coveredDisruptions,
    );
    _persist();
  }

  void setPaymentComplete() {
    state = state.copyWith(paymentComplete: true);
    clearSaved();
  }

  // Builds the rider PATCH payload for the backend
  Map<String, dynamic> buildRiderUpdatePayload(String phone) => {
        'fullName': state.fullName,
        'phone': phone,
        'city': state.city,
        'platform': state.platform,
        'operatingZone': state.operatingZone.isNotEmpty
            ? state.operatingZone
            : state.city,
        'operatingPincode': state.operatingPincode.isNotEmpty
            ? state.operatingPincode
            : '000000',
        'avgWeeklyEarnings': state.weeklyEarningsPaise,
        'avgDailyHours': state.dailyHours,
        'preferredShift': state.preferredShift,
        'vehicleType': state.vehicleType,
        'experienceMonths': state.experienceMonths,
        if (state.lat != null && state.lng != null)
          'location': {'lat': state.lat, 'lng': state.lng},
        if (state.riskScore != null) 'riskScore': state.riskScore,
        if (state.riskTier != null) 'riskTier': state.riskTier,
      };

  // Builds the ML features payload
  Map<String, dynamic> buildMLFeatures() => {
        'city': state.city,
        'vehicle_type': state.vehicleType.toLowerCase(),
        'platform': state.platform.toLowerCase(),
        'avg_weekly_earnings': state.weeklyEarningsPaise / 100,
        'avg_daily_hours': state.dailyHours,
        'experience_months': state.experienceMonths,
        'preferred_shift': state.preferredShift.toLowerCase(),
        if (state.lat != null) 'lat': state.lat,
        if (state.lng != null) 'lng': state.lng,
      };
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingData>(
        (ref) => OnboardingNotifier());
