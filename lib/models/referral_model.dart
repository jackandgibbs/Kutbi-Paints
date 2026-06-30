class ReferralModel {
  final String id;
  final String referrerId;
  final String? referredId;
  final String referralCode;
  final double bonusPoints;
  final String status; // 'pending', 'completed'
  final DateTime createdAt;

  ReferralModel({
    required this.id,
    required this.referrerId,
    this.referredId,
    required this.referralCode,
    this.bonusPoints = 0,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id: json['id'] ?? '',
      referrerId: json['referrer_id'] ?? '',
      referredId: json['referred_id'],
      referralCode: json['referral_code'] ?? '',
      bonusPoints: (json['bonus_points'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referrer_id': referrerId,
      'referred_id': referredId,
      'referral_code': referralCode,
      'bonus_points': bonusPoints,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
