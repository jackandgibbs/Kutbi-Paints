class GoalModel {
  final String id;
  final String title;
  final String? description;
  final String brand;
  final int targetQuantity;
  final double rewardAmount;
  final String rewardType; // 'cashback', 'discount', 'gift'
  final List<String> assignedTo; // painter IDs, or ['all'] for everyone
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.title,
    this.description,
    required this.brand,
    required this.targetQuantity,
    required this.rewardAmount,
    this.rewardType = 'cashback',
    required this.assignedTo,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      brand: json['brand'] ?? '',
      targetQuantity: json['target_quantity'] ?? 0,
      rewardAmount: (json['reward_amount'] ?? 0).toDouble(),
      rewardType: json['reward_type'] ?? 'cashback',
      assignedTo: List<String>.from(json['assigned_to'] ?? []),
      startDate:
          DateTime.tryParse(json['start_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      isActive: json['is_active'] ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'brand': brand,
      'target_quantity': targetQuantity,
      'reward_amount': rewardAmount,
      'reward_type': rewardType,
      'assigned_to': assignedTo,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class RewardModel {
  final String id;
  final String painterId;
  final String goalId;
  final double rewardAmount;
  final String status; // 'earned', 'redeemed'
  final DateTime earnedAt;

  RewardModel({
    required this.id,
    required this.painterId,
    required this.goalId,
    required this.rewardAmount,
    required this.status,
    required this.earnedAt,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      id: json['id'] ?? '',
      painterId: json['painter_id'] ?? '',
      goalId: json['goal_id'] ?? '',
      rewardAmount: (json['reward_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'earned',
      earnedAt: DateTime.tryParse(json['earned_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'painter_id': painterId,
      'goal_id': goalId,
      'reward_amount': rewardAmount,
      'status': status,
      'earned_at': earnedAt.toIso8601String(),
    };
  }
}
