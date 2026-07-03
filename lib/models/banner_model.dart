class BannerModel {
  final String id;
  final String imageUrl;
  final String? title;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  BannerModel({
    required this.id,
    required this.imageUrl,
    this.title,
    this.isActive = true,
    this.sortOrder = 100,
    required this.createdAt,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      title: json['title'],
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 100,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'image_url': imageUrl,
        'title': title,
        'is_active': isActive,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };
}
