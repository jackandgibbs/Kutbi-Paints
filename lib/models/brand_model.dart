class BrandModel {
  final String id;
  final String name;
  final String? logoUrl;
  final int sortOrder;
  final DateTime createdAt;

  BrandModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.sortOrder = 100,
    required this.createdAt,
  });

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logoUrl: json['logo_url'],
      sortOrder: json['sort_order'] ?? 100,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  BrandModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return BrandModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
