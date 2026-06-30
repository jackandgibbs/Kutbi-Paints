class ProductModel {
  final String id;
  final String name;
  final String brand; // 'Asian Paints', 'Berger', 'Birla Opus'
  final String category; // 'Interior', 'Exterior', 'Putty', 'Oil Paint'
  final String subCategory; // 'Premium', 'Luxury', 'Emulsion', 'Distemper'
  final String colorCode;
  final String colorName;
  final String colorHex;
  final String? description;
  final String? imageUrl;
  final List<String> bucketSizes;
  final Map<String, double> prices; // {'1L': 250, '4L': 900, ...}
  final Map<String, double>? goldPrices;
  final Map<String, double>? silverPrices;
  final Map<String, int>? variantStock; // {'1L': 10, '20L': 5}
  final int stockLevel;
  final int lowStockThreshold;
  final String unit; // 'ML', 'L', 'KG', 'G'
  final int minQuantity;
  final bool hasColorShade;
  final bool isOutOfStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.subCategory,
    required this.colorCode,
    required this.colorName,
    required this.colorHex,
    this.description,
    this.imageUrl,
    required this.bucketSizes,
    required this.prices,
    this.goldPrices,
    this.silverPrices,
    this.variantStock,
    required this.stockLevel,
    this.lowStockThreshold = 10,
    this.unit = 'L',
    this.minQuantity = 1,
    this.hasColorShade = true,
    this.isOutOfStock = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => totalStock <= lowStockThreshold;
  bool get isEffectivelyOutOfStock => isOutOfStock || totalStock <= 0;

  int get totalStock {
    if (variantStock != null && variantStock!.isNotEmpty) {
      return variantStock!.values.fold(0, (sum, val) => sum + val);
    }
    return stockLevel;
  }

  List<String> get availableSizes => availableBucketSizes;

  List<String> get availableBucketSizes {
    if (bucketSizes.isNotEmpty) return bucketSizes;
    if (prices.isNotEmpty) return prices.keys.toList();
    return const ['1L'];
  }

  double get startingPrice {
    if (prices.isNotEmpty) return prices.values.first;
    return 0;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final parsedPrices = Map<String, double>.from(
      (json['prices'] ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    );
    final parsedBucketSizes = List<String>.from(
      json['bucket_sizes'] ?? const ['1L', '4L', '10L', '20L'],
    );
    final normalizedBucketSizes = parsedBucketSizes.isNotEmpty
        ? parsedBucketSizes
        : (parsedPrices.isNotEmpty ? parsedPrices.keys.toList() : const ['1L']);
    final normalizedPrices = parsedPrices.isNotEmpty
        ? parsedPrices
        : {
            for (final size in normalizedBucketSizes) size: 0.0,
          };

    final hasShade = json['has_color_shade'] ?? _shouldRequireShade(json['name'] ?? '', json['category'] ?? '');
    
    final vStock = json['variant_stock'] != null 
      ? Map<String, int>.from(json['variant_stock'].map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
      : null;

    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? 'Interior',
      subCategory: json['sub_category'] ?? 'Premium',
      colorCode: json['color_code'] ?? '',
      colorName: json['color_name'] ?? '',
      colorHex: json['color_hex'] ?? '#FFFFFF',
      description: json['description'],
      imageUrl: json['image_url'],
      bucketSizes: normalizedBucketSizes,
      prices: normalizedPrices,
      goldPrices: json['gold_prices'] != null
          ? Map<String, double>.from(
              json['gold_prices'].map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            )
          : null,
      silverPrices: json['silver_prices'] != null
          ? Map<String, double>.from(
              json['silver_prices'].map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            )
          : null,
      variantStock: vStock,
      stockLevel: json['stock_level'] ?? 0,
      lowStockThreshold: json['low_stock_threshold'] ?? 10,
      unit: json['unit'] ?? 'L',
      minQuantity: json['min_quantity'] ?? 1,
      hasColorShade: hasShade is bool ? hasShade : (hasShade == 1 || hasShade == 'true'),
      isOutOfStock: json['is_out_of_stock'] == true || json['is_out_of_stock'] == 1 || json['is_out_of_stock'] == 'true',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  static bool _shouldRequireShade(String name, String category) {
    final cat = category.toLowerCase();
    final n = name.toLowerCase();
    if (cat.contains('putty') || n.contains('putty')) return false;
    if (cat.contains('primer') || n.contains('primer')) return false;
    if (cat.contains('waterproofing') || cat.contains('alldry') || n.contains('damp')) return false;
    return true;
  }

  Map<String, dynamic> toJson() {
    final safeBucketSizes = bucketSizes.isNotEmpty ? bucketSizes : availableBucketSizes;
    final safePrices = prices.isNotEmpty
        ? prices
        : {
            for (final size in safeBucketSizes) size: 0.0,
          };

    return {
      'id': id,
      'name': name,
      'brand': brand,
      'category': category,
      'sub_category': subCategory,
      'color_code': colorCode,
      'color_name': colorName,
      'color_hex': colorHex,
      'description': description,
      'image_url': imageUrl,
      'bucket_sizes': safeBucketSizes,
      'prices': safePrices,
      'gold_prices': goldPrices,
      'silver_prices': silverPrices,
      'variant_stock': variantStock,
      'stock_level': stockLevel,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'min_quantity': minQuantity,
      'has_color_shade': hasColorShade,
      'is_out_of_stock': isOutOfStock,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? colorCode,
    String? colorName,
    String? colorHex,
    String? description,
    String? imageUrl,
    List<String>? bucketSizes,
    Map<String, double>? prices,
    Map<String, double>? goldPrices,
    Map<String, double>? silverPrices,
    String? category,
    String? subCategory,
    Map<String, int>? variantStock,
    int? stockLevel,
    int? lowStockThreshold,
    String? unit,
    int? minQuantity,
    bool? hasColorShade,
    bool? isOutOfStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      colorCode: colorCode ?? this.colorCode,
      colorName: colorName ?? this.colorName,
      colorHex: colorHex ?? this.colorHex,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      bucketSizes: bucketSizes ?? this.bucketSizes,
      prices: prices ?? this.prices,
      goldPrices: goldPrices ?? this.goldPrices,
      silverPrices: silverPrices ?? this.silverPrices,
      variantStock: variantStock ?? this.variantStock,
      stockLevel: stockLevel ?? this.stockLevel,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unit: unit ?? this.unit,
      minQuantity: minQuantity ?? this.minQuantity,
      hasColorShade: hasColorShade ?? this.hasColorShade,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
