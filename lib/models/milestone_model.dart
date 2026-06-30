class MilestoneModel {
  final String id;
  final int targetPoints;
  final String rewardTitle;
  final String rewardType; // 'discount', 'gift', 'cashback', etc.
  final DateTime createdAt;

  MilestoneModel({
    required this.id,
    required this.targetPoints,
    required this.rewardTitle,
    required this.rewardType,
    required this.createdAt,
  });

  factory MilestoneModel.fromJson(Map<String, dynamic> json) {
    return MilestoneModel(
      id: json['id'] ?? '',
      targetPoints: json['target_points'] ?? 0,
      rewardTitle: json['reward_title'] ?? '',
      rewardType: json['reward_type'] ?? 'gift',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_points': targetPoints,
      'reward_title': rewardTitle,
      'reward_type': rewardType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
