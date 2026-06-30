class OrderItemModel {
  final String productId;
  final String productName;
  final String colorCode;
  final String colorName;
  final String colorHex;
  final int quantity;
  final String bucketSize;
  final double unitPrice;
  final double totalPrice;
  final String? shadeCode;

  final String? productImageUrl;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.colorCode,
    required this.colorName,
    required this.colorHex,
    required this.quantity,
    required this.bucketSize,
    required this.unitPrice,
    required this.totalPrice,
    this.shadeCode,
    this.productImageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      colorCode: json['color_code'] ?? '',
      colorName: json['color_name'] ?? '',
      colorHex: json['color_hex'] ?? '#FFFFFF',
      quantity: json['quantity'] ?? 0,
      bucketSize: json['bucket_size'] ?? '1L',
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      totalPrice: (json['total_price'] ?? 0).toDouble(),
      shadeCode: json['shade_code'],
      productImageUrl: json['product_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'color_code': colorCode,
      'color_name': colorName,
      'color_hex': colorHex,
      'quantity': quantity,
      'bucket_size': bucketSize,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'shade_code': shadeCode,
      'product_image_url': productImageUrl,
    };
  }

  OrderItemModel copyWith({
    String? productId,
    String? productName,
    String? colorCode,
    String? colorName,
    String? colorHex,
    int? quantity,
    String? bucketSize,
    double? unitPrice,
    double? totalPrice,
    String? shadeCode,
    String? productImageUrl,
  }) {
    return OrderItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      colorCode: colorCode ?? this.colorCode,
      colorName: colorName ?? this.colorName,
      colorHex: colorHex ?? this.colorHex,
      quantity: quantity ?? this.quantity,
      bucketSize: bucketSize ?? this.bucketSize,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      shadeCode: shadeCode ?? this.shadeCode,
      productImageUrl: productImageUrl ?? this.productImageUrl,
    );
  }
}

class OrderModel {
  final String id;
  final String painterId;
  final String? painterName;
  final String? painterPhone;
  final String brand;
  final List<OrderItemModel> items;
  final String siteLocation;
  final double? siteLat;
  final double? siteLng;
  final String paymentMethod; // 'pending', 'online', 'cash', 'udhaari'
  final double totalAmount;
  final String status; // 'pending_bill', 'bill_sent', 'payment_selected', 'placed', 'accepted', 'preparing', 'dispatched', 'delivered'
  final String? billImageUrl;
  final String paymentStatus; // 'pending', 'partially_paid', 'fully_paid', 'udhaari', 'refunded'
  final double paidAmount;
  final bool udhaariInterestEnabled;
  final double udhaariInterestRate;
  final double udhaariInterestAmount;
  final bool refundCompleted;
  final bool deletedByAdmin;
  final bool hideAmount; // If true, painter sees '--' instead of amount
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.painterId,
    this.painterName,
    this.painterPhone,
    required this.brand,
    required this.items,
    required this.siteLocation,
    this.siteLat,
    this.siteLng,
    required this.paymentMethod,
    required this.totalAmount,
    required this.status,
    this.billImageUrl,
    this.paymentStatus = 'pending',
    this.paidAmount = 0,
    this.udhaariInterestEnabled = false,
    this.udhaariInterestRate = 0.0,
    this.udhaariInterestAmount = 0.0,
    this.refundCompleted = false,
    this.deletedByAdmin = false,
    this.hideAmount = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      painterId: json['painter_id'] ?? '',
      painterName: json['painter_name'],
      painterPhone: json['painter_phone'],
      brand: json['brand'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      siteLocation: json['site_location'] ?? '',
      siteLat: (json['site_lat'] as num?)?.toDouble(),
      siteLng: (json['site_lng'] as num?)?.toDouble(),
      paymentMethod: json['payment_method'] ?? 'pending',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending_bill',
      billImageUrl: json['bill_image_url'],
      paymentStatus: json['payment_status'] ?? 'pending',
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      udhaariInterestEnabled: json['udhaari_interest_enabled'] ?? false,
      udhaariInterestRate: (json['udhaari_interest_rate'] ?? 0).toDouble(),
      udhaariInterestAmount: (json['udhaari_interest_amount'] ?? 0).toDouble(),
      refundCompleted: json['refund_completed'] ?? false,
      deletedByAdmin: json['deleted_by_admin'] ?? false,
      hideAmount: json['hide_amount'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'painter_id': painterId,
      'painter_name': painterName,
      'painter_phone': painterPhone,
      'brand': brand,
      'items': items.map((e) => e.toJson()).toList(),
      'site_location': siteLocation,
      'site_lat': siteLat,
      'site_lng': siteLng,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'status': status,
      'bill_image_url': billImageUrl,
      'payment_status': paymentStatus,
      'paid_amount': paidAmount,
      'udhaari_interest_enabled': udhaariInterestEnabled,
      'udhaari_interest_rate': udhaariInterestRate,
      'udhaari_interest_amount': udhaariInterestAmount,
      'refund_completed': refundCompleted,
      'deleted_by_admin': deletedByAdmin,
      'hide_amount': hideAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? painterId,
    String? painterName,
    String? painterPhone,
    String? brand,
    List<OrderItemModel>? items,
    String? siteLocation,
    double? siteLat,
    double? siteLng,
    String? paymentMethod,
    double? totalAmount,
    String? status,
    String? billImageUrl,
    String? paymentStatus,
    double? paidAmount,
    bool? udhaariInterestEnabled,
    double? udhaariInterestRate,
    double? udhaariInterestAmount,
    bool? refundCompleted,
    bool? deletedByAdmin,
    bool? hideAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      painterId: painterId ?? this.painterId,
      painterName: painterName ?? this.painterName,
      painterPhone: painterPhone ?? this.painterPhone,
      brand: brand ?? this.brand,
      items: items ?? this.items,
      siteLocation: siteLocation ?? this.siteLocation,
      siteLat: siteLat ?? this.siteLat,
      siteLng: siteLng ?? this.siteLng,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      billImageUrl: billImageUrl ?? this.billImageUrl,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      udhaariInterestEnabled: udhaariInterestEnabled ?? this.udhaariInterestEnabled,
      udhaariInterestRate: udhaariInterestRate ?? this.udhaariInterestRate,
      udhaariInterestAmount: udhaariInterestAmount ?? this.udhaariInterestAmount,
      refundCompleted: refundCompleted ?? this.refundCompleted,
      deletedByAdmin: deletedByAdmin ?? this.deletedByAdmin,
      hideAmount: hideAmount ?? this.hideAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Whether this order is in the pre-billing phase (not yet visible in Orders tab)
  bool get isPendingBilling => status == 'pending_bill';
  bool get isUdhaariRequested => status == 'udhaari_requested';
  bool get isPendingReveal => status == 'pending_reveal';
  bool get isToBeRevealed => status == 'to_be_revealed';
  bool get isUdhaariPendingApproval => status == 'udhaari_pending_approval';
  
  bool get isConfirmed => 
    status != 'pending_bill' && 
    status != 'udhaari_requested' &&
    status != 'udhaari_pending_approval' &&
    status != 'to_be_revealed' &&
    status != 'cancelled';

  bool get canBeCancelled => status == 'pending_bill' || status == 'udhaari_requested' || status == 'udhaari_pending_approval' || status == 'to_be_revealed';

  /// Remaining amount dynamically calculated based on paid amount and udhaari interest
  double get remainingAmount {
    return (totalAmount + udhaariInterestAmount) - paidAmount;
  }
}
