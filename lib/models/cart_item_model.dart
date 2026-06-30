class CartItemModel {
  final String productId;
  final String productName;
  final String productImageUrl;
  final String bucketSize;
  final String? shadeCode;
  final double price; // Base price or estimated
  int quantity;

  CartItemModel({
    required this.productId,
    required this.productName,
    required this.productImageUrl,
    required this.bucketSize,
    this.shadeCode,
    required this.price,
    this.quantity = 1,
  });

  double get total => price * quantity;

  CartItemModel copyWith({
    String? productId,
    String? productName,
    String? productImageUrl,
    String? bucketSize,
    String? shadeCode,
    double? price,
    int? quantity,
  }) {
    return CartItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      bucketSize: bucketSize ?? this.bucketSize,
      shadeCode: shadeCode ?? this.shadeCode,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }
}
