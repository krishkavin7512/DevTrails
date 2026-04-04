/// Community alert — planned backend feature.
/// Shape mirrors what the alerts API will return when implemented.
class Alert {
  final String id;
  final String riderId;
  final String type; // HeavyRain | Flooding | Accident | RoadBlock | Police | Other
  final String description;
  final String city;
  final double lat;
  final double lng;
  final int confirmations;
  final int trustImpact; // positive = trusted, negative = disputed
  final bool verified;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const Alert({
    required this.id,
    required this.riderId,
    required this.type,
    required this.description,
    required this.city,
    required this.lat,
    required this.lng,
    required this.confirmations,
    required this.trustImpact,
    required this.verified,
    required this.createdAt,
    this.expiresAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['_id'] ?? json['id'] ?? '',
        riderId: json['riderId']?.toString() ?? '',
        type: json['type'] ?? 'Other',
        description: json['description'] ?? '',
        city: json['city'] ?? '',
        lat: (json['location']?['lat'] ?? 0).toDouble(),
        lng: (json['location']?['lng'] ?? 0).toDouble(),
        confirmations: (json['confirmations'] ?? 0) as int,
        trustImpact: (json['trustImpact'] ?? 0) as int,
        verified: json['verified'] ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'city': city,
        'location': {'lat': lat, 'lng': lng},
      };

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
