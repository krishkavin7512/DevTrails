class RiderLocation {
  final double lat;
  final double lng;

  const RiderLocation({required this.lat, required this.lng});

  factory RiderLocation.fromJson(Map<String, dynamic> json) => RiderLocation(
        lat: (json['lat'] ?? 0).toDouble(),
        lng: (json['lng'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class Rider {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String city;
  final String platform; // Zomato | Swiggy | Both
  final String operatingZone;
  final String operatingPincode;
  final int avgWeeklyEarnings; // paise
  final int avgDailyHours;
  final String preferredShift; // Morning | Afternoon | Evening | Night | Mixed
  final String vehicleType; // Bicycle | Scooter | Motorcycle
  final int experienceMonths;
  final String riskTier; // Low | Medium | High | VeryHigh
  final double riskScore;
  final bool isActive;
  final bool kycVerified;
  final RiderLocation location;
  final DateTime registeredAt;
  final DateTime lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rider({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    required this.city,
    required this.platform,
    required this.operatingZone,
    required this.operatingPincode,
    required this.avgWeeklyEarnings,
    required this.avgDailyHours,
    required this.preferredShift,
    required this.vehicleType,
    required this.experienceMonths,
    required this.riskTier,
    required this.riskScore,
    required this.isActive,
    required this.kycVerified,
    required this.location,
    required this.registeredAt,
    required this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Rider(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      city: json['city'] ?? '',
      platform: json['platform'] ?? 'Both',
      operatingZone: json['operatingZone'] ?? '',
      operatingPincode: json['operatingPincode'] ?? '',
      avgWeeklyEarnings: (json['avgWeeklyEarnings'] ?? 0) as int,
      avgDailyHours: (json['avgDailyHours'] ?? 8) as int,
      preferredShift: json['preferredShift'] ?? 'Mixed',
      vehicleType: json['vehicleType'] ?? 'Scooter',
      experienceMonths: (json['experienceMonths'] ?? 0) as int,
      riskTier: json['riskTier'] ?? 'Medium',
      riskScore: (json['riskScore'] ?? 50).toDouble(),
      isActive: json['isActive'] ?? true,
      kycVerified: json['kycVerified'] ?? false,
      location: RiderLocation.fromJson(
          (json['location'] as Map<String, dynamic>?) ?? {}),
      registeredAt:
          DateTime.tryParse(json['registeredAt'] ?? '') ?? now,
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt'] ?? '') ?? now,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'city': city,
        'platform': platform,
        'operatingZone': operatingZone,
        'operatingPincode': operatingPincode,
        'avgWeeklyEarnings': avgWeeklyEarnings,
        'avgDailyHours': avgDailyHours,
        'preferredShift': preferredShift,
        'vehicleType': vehicleType,
        'experienceMonths': experienceMonths,
        'location': location.toJson(),
      };

  // Convenience getters
  String get weeklyEarningsFormatted =>
      '₹${(avgWeeklyEarnings / 100).toStringAsFixed(0)}';
  String get initials => fullName.isNotEmpty
      ? fullName.split(' ').map((w) => w[0]).take(2).join().toUpperCase()
      : 'R';
}
