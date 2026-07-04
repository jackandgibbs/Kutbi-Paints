class BrandModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? coverImageUrl;
  final int sortOrder;
  final DateTime createdAt;

  BrandModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.coverImageUrl,
    this.sortOrder = 100,
    required this.createdAt,
  });

  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
  bool get hasCover => coverImageUrl != null && coverImageUrl!.isNotEmpty;

  /// The image to use as the large brand header/cover. Falls back to the logo
  /// when no dedicated cover has been uploaded.
  String? get headerImageUrl => hasCover ? coverImageUrl : logoUrl;

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      logoUrl: json['logo_url'],
      coverImageUrl: json['cover_image_url'],
      sortOrder: json['sort_order'] ?? 100,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
    // Only include cover_image_url when set, so brand creation keeps working
    // even before the cover_image_url column migration has been applied.
    if (coverImageUrl != null) {
      map['cover_image_url'] = coverImageUrl;
    }
    return map;
  }

  BrandModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? coverImageUrl,
    bool clearCoverImage = false,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return BrandModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      coverImageUrl:
          clearCoverImage ? null : (coverImageUrl ?? this.coverImageUrl),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
