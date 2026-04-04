class TriggerData {
  final String parameter;
  final double threshold;
  final double actualValue;
  final String dataSource;
  final DateTime timestamp;
  final double lat;
  final double lng;

  const TriggerData({
    required this.parameter,
    required this.threshold,
    required this.actualValue,
    required this.dataSource,
    required this.timestamp,
    required this.lat,
    required this.lng,
  });

  factory TriggerData.fromJson(Map<String, dynamic> json) => TriggerData(
        parameter: json['parameter'] ?? '',
        threshold: (json['threshold'] ?? 0).toDouble(),
        actualValue: (json['actualValue'] ?? 0).toDouble(),
        dataSource: json['dataSource'] ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        lat: (json['location']?['lat'] ?? 0).toDouble(),
        lng: (json['location']?['lng'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'parameter': parameter,
        'threshold': threshold,
        'actualValue': actualValue,
        'dataSource': dataSource,
        'timestamp': timestamp.toIso8601String(),
        'location': {'lat': lat, 'lng': lng},
      };

  double get overagePercent => threshold > 0
      ? ((actualValue - threshold) / threshold * 100)
      : 0;
}

class Claim {
  final String id;
  final String policyId;
  final String riderId;
  final String claimNumber;
  final String triggerType; // HeavyRain | ExtremeHeat | SevereAQI | Flooding | SocialDisruption
  final TriggerData triggerData;
  final double estimatedLostHours;
  final int payoutAmount; // paise
  final String status; // AutoInitiated | UnderReview | Approved | Paid | Rejected | FraudSuspected
  final double fraudScore; // 0–100
  final List<String> fraudFlags;
  final DateTime? processedAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Claim({
    required this.id,
    required this.policyId,
    required this.riderId,
    required this.claimNumber,
    required this.triggerType,
    required this.triggerData,
    required this.estimatedLostHours,
    required this.payoutAmount,
    required this.status,
    required this.fraudScore,
    required this.fraudFlags,
    this.processedAt,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Claim(
      id: json['_id'] ?? json['id'] ?? '',
      policyId: json['policyId']?.toString() ?? '',
      riderId: json['riderId']?.toString() ?? '',
      claimNumber: json['claimNumber'] ?? '',
      triggerType: json['triggerType'] ?? '',
      triggerData: TriggerData.fromJson(
          (json['triggerData'] as Map<String, dynamic>?) ?? {}),
      estimatedLostHours:
          (json['estimatedLostHours'] ?? 0).toDouble(),
      payoutAmount: (json['payoutAmount'] ?? 0) as int,
      status: json['status'] ?? 'AutoInitiated',
      fraudScore: (json['fraudScore'] ?? 0).toDouble(),
      fraudFlags: List<String>.from(json['fraudFlags'] ?? []),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'])
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'policyId': policyId,
        'riderId': riderId,
        'triggerType': triggerType,
        'triggerData': triggerData.toJson(),
        'estimatedLostHours': estimatedLostHours,
        'payoutAmount': payoutAmount,
      };

  bool get isPaid => status == 'Paid';
  bool get isPending =>
      status == 'AutoInitiated' || status == 'UnderReview';
  bool get isFlagged =>
      status == 'FraudSuspected' || fraudScore > 70;

  String get payoutFormatted =>
      '₹${(payoutAmount / 100).toStringAsFixed(0)}';
  String get fraudScorePercent =>
      '${fraudScore.toStringAsFixed(0)}%';
}
