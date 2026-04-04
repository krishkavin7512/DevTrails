class Policy {
  final String id;
  final String riderId;
  final String planType; // Basic | Standard | Premium
  final int weeklyPremium; // paise
  final int coverageLimit; // paise
  final List<String> coveredDisruptions;
  final String status; // Active | Expired | Cancelled | PendingPayment
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final String policyNumber;
  final int renewalCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Policy({
    required this.id,
    required this.riderId,
    required this.planType,
    required this.weeklyPremium,
    required this.coverageLimit,
    required this.coveredDisruptions,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.autoRenew,
    required this.policyNumber,
    required this.renewalCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Policy(
      id: json['_id'] ?? json['id'] ?? '',
      riderId: json['riderId']?.toString() ?? '',
      planType: json['planType'] ?? 'Basic',
      weeklyPremium: (json['weeklyPremium'] ?? 0) as int,
      coverageLimit: (json['coverageLimit'] ?? 0) as int,
      coveredDisruptions:
          List<String>.from(json['coveredDisruptions'] ?? []),
      status: json['status'] ?? 'PendingPayment',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? now,
      endDate: DateTime.tryParse(json['endDate'] ?? '') ??
          now.add(const Duration(days: 7)),
      autoRenew: json['autoRenew'] ?? true,
      policyNumber: json['policyNumber'] ?? '',
      renewalCount: (json['renewalCount'] ?? 0) as int,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'riderId': riderId,
        'planType': planType,
        'weeklyPremium': weeklyPremium,
        'coverageLimit': coverageLimit,
        'coveredDisruptions': coveredDisruptions,
        'status': status,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'autoRenew': autoRenew,
        'policyNumber': policyNumber,
      };

  bool get isActive => status == 'Active';
  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  String get weeklyPremiumFormatted =>
      '₹${(weeklyPremium / 100).toStringAsFixed(0)}';
  String get coverageLimitFormatted =>
      '₹${(coverageLimit / 100).toStringAsFixed(0)}';
}
