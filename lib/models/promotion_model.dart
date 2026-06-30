class PromotionModel {
  final String id;
  final String title;
  final String brand; // Brand this promotion applies to
  final double discountPercent; // Multiplier like 0.1 for 10%
  final double discountFlat; // Flat rate like ₹50 off per bucket
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  PromotionModel({
    required this.id,
    required this.title,
    required this.brand,
    required this.discountPercent,
    required this.discountFlat,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountFlat: (json['discount_flat'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'brand': brand,
      'discount_percent': discountPercent,
      'discount_flat': discountFlat,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper to check if promotion is currently valid by time
  bool get isValidNow {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }
}
