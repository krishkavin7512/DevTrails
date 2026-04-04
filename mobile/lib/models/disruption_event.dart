class EventTriggerData {
  final String parameter;
  final double value;
  final double threshold;

  const EventTriggerData({
    required this.parameter,
    required this.value,
    required this.threshold,
  });

  factory EventTriggerData.fromJson(Map<String, dynamic> json) =>
      EventTriggerData(
        parameter: json['parameter'] ?? '',
        value: (json['value'] ?? 0).toDouble(),
        threshold: (json['threshold'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'parameter': parameter,
        'value': value,
        'threshold': threshold,
      };
}

class DisruptionEvent {
  final String id;
  final String city;
  final List<String> zones;
  final String type; // HeavyRain | ExtremeHeat | SevereAQI | Flooding | SocialDisruption
  final String severity; // Moderate | Severe | Extreme
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final EventTriggerData triggerData;
  final int affectedRiders;
  final int totalPayouts; // paise
  final int claimsGenerated;
  final bool isActive;
  final String source; // Automated | AdminTriggered | CommunityReport
  final DateTime createdAt;
  final DateTime updatedAt;

  const DisruptionEvent({
    required this.id,
    required this.city,
    required this.zones,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.startTime,
    this.endTime,
    required this.triggerData,
    required this.affectedRiders,
    required this.totalPayouts,
    required this.claimsGenerated,
    required this.isActive,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DisruptionEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return DisruptionEvent(
      id: json['_id'] ?? json['id'] ?? '',
      city: json['city'] ?? '',
      zones: List<String>.from(json['zones'] ?? []),
      type: json['type'] ?? '',
      severity: json['severity'] ?? 'Moderate',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startTime: DateTime.tryParse(json['startTime'] ?? '') ?? now,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'])
          : null,
      triggerData: EventTriggerData.fromJson(
          (json['triggerData'] as Map<String, dynamic>?) ?? {}),
      affectedRiders: (json['affectedRiders'] ?? 0) as int,
      totalPayouts: (json['totalPayouts'] ?? 0) as int,
      claimsGenerated: (json['claimsGenerated'] ?? 0) as int,
      isActive: json['isActive'] ?? false,
      source: json['source'] ?? 'Automated',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'zones': zones,
        'type': type,
        'severity': severity,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'triggerData': triggerData.toJson(),
        'source': source,
      };

  String get totalPayoutsFormatted =>
      '₹${(totalPayouts / 100).toStringAsFixed(0)}';
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);
}
