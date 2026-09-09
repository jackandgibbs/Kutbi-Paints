// ============================================================================
// Return / Refund System — Model Layer
// ============================================================================
//
// ReturnStatus    — enum of all 9 lifecycle statuses
// ReturnRequestItemModel — mirrors return_request_items table
// ReturnRequestModel     — mirrors return_requests table
//
// Design note: orders.items is a JSONB array with no per-item UUID.
// Return items reference their position via [itemIndex] (0-based).
// ============================================================================

/// Number of days after delivery within which a return may be requested.
/// Change this single constant to adjust the return window app-wide.
const int kReturnWindowDays = 7;

/// Predefined return reasons (shown to painter in UI).
const List<String> kReturnReasons = [
  'Damaged product',
  'Wrong product',
  'Defective product',
  'Product not as expected',
  'Missing/damaged packaging',
  'Changed my mind',
  'Other',
];

// ---------------------------------------------------------------------------
// ReturnStatus
// ---------------------------------------------------------------------------
enum ReturnStatus {
  requested,
  approved,
  pickupScheduled,
  pickedUp,
  received,
  refundProcessing,
  refunded,
  rejected,
  cancelled;

  /// Parse from database string value.
  static ReturnStatus fromString(String value) {
    switch (value) {
      case 'requested':
        return ReturnStatus.requested;
      case 'approved':
        return ReturnStatus.approved;
      case 'pickup_scheduled':
        return ReturnStatus.pickupScheduled;
      case 'picked_up':
        return ReturnStatus.pickedUp;
      case 'received':
        return ReturnStatus.received;
      case 'refund_processing':
        return ReturnStatus.refundProcessing;
      case 'refunded':
        return ReturnStatus.refunded;
      case 'rejected':
        return ReturnStatus.rejected;
      case 'cancelled':
        return ReturnStatus.cancelled;
      default:
        return ReturnStatus.requested;
    }
  }

  /// Database/API string representation.
  String get value {
    switch (this) {
      case ReturnStatus.requested:
        return 'requested';
      case ReturnStatus.approved:
        return 'approved';
      case ReturnStatus.pickupScheduled:
        return 'pickup_scheduled';
      case ReturnStatus.pickedUp:
        return 'picked_up';
      case ReturnStatus.received:
        return 'received';
      case ReturnStatus.refundProcessing:
        return 'refund_processing';
      case ReturnStatus.refunded:
        return 'refunded';
      case ReturnStatus.rejected:
        return 'rejected';
      case ReturnStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Human-readable display label.
  String get label {
    switch (this) {
      case ReturnStatus.requested:
        return 'Return Requested';
      case ReturnStatus.approved:
        return 'Return Approved';
      case ReturnStatus.pickupScheduled:
        return 'Pickup Scheduled';
      case ReturnStatus.pickedUp:
        return 'Picked Up';
      case ReturnStatus.received:
        return 'Product Received';
      case ReturnStatus.refundProcessing:
        return 'Refund Processing';
      case ReturnStatus.refunded:
        return 'Refund Completed';
      case ReturnStatus.rejected:
        return 'Return Rejected';
      case ReturnStatus.cancelled:
        return 'Return Cancelled';
    }
  }

  /// Whether cancellation is allowed in this status (by the painter).
  bool get canBeCancelledByUser =>
      this == ReturnStatus.requested || this == ReturnStatus.approved;

  /// Whether the status represents a terminal (final) state.
  bool get isTerminal =>
      this == ReturnStatus.refunded ||
      this == ReturnStatus.rejected ||
      this == ReturnStatus.cancelled;

  /// Returns the valid next statuses for admin progression.
  List<ReturnStatus> get allowedNextStatuses {
    switch (this) {
      case ReturnStatus.requested:
        return [ReturnStatus.approved, ReturnStatus.rejected, ReturnStatus.cancelled];
      case ReturnStatus.approved:
        return [ReturnStatus.pickupScheduled, ReturnStatus.cancelled];
      case ReturnStatus.pickupScheduled:
        return [ReturnStatus.pickedUp];
      case ReturnStatus.pickedUp:
        return [ReturnStatus.received];
      case ReturnStatus.received:
        return [ReturnStatus.refundProcessing];
      case ReturnStatus.refundProcessing:
        return [ReturnStatus.refunded];
      default:
        return [];
    }
  }
}

// ---------------------------------------------------------------------------
// ReturnRequestItemModel
// ---------------------------------------------------------------------------
class ReturnRequestItemModel {
  final String id;
  final String returnRequestId;
  final String orderId;
  final int itemIndex; // 0-based position in orders.items JSONB
  final String productId;
  final String productName;
  final String bucketSize;
  final double unitPrice;
  final String? colorName;
  final String? colorHex;
  final int quantity;
  final String? reason;
  final String condition; // 'good','damaged','opened','unused','unknown'
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReturnRequestItemModel({
    required this.id,
    required this.returnRequestId,
    required this.orderId,
    required this.itemIndex,
    required this.productId,
    required this.productName,
    required this.bucketSize,
    required this.unitPrice,
    this.colorName,
    this.colorHex,
    required this.quantity,
    this.reason,
    this.condition = 'unknown',
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalPrice => unitPrice * quantity;

  factory ReturnRequestItemModel.fromJson(Map<String, dynamic> json) {
    return ReturnRequestItemModel(
      id: json['id'] ?? '',
      returnRequestId: json['return_request_id'] ?? '',
      orderId: json['order_id'] ?? '',
      itemIndex: (json['item_index'] ?? 0).toInt(),
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      bucketSize: json['bucket_size'] ?? '1L',
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      colorName: json['color_name'],
      colorHex: json['color_hex'],
      quantity: (json['quantity'] ?? 1).toInt(),
      reason: json['reason'],
      condition: json['condition'] ?? 'unknown',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'return_request_id': returnRequestId,
      'order_id': orderId,
      'item_index': itemIndex,
      'product_id': productId,
      'product_name': productName,
      'bucket_size': bucketSize,
      'unit_price': unitPrice,
      'color_name': colorName,
      'color_hex': colorHex,
      'quantity': quantity,
      'reason': reason,
      'condition': condition,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    // Excludes id/timestamps — let Supabase generate them
    return {
      'return_request_id': returnRequestId,
      'order_id': orderId,
      'item_index': itemIndex,
      'product_id': productId,
      'product_name': productName,
      'bucket_size': bucketSize,
      'unit_price': unitPrice,
      'color_name': colorName,
      'color_hex': colorHex,
      'quantity': quantity,
      'reason': reason,
      'condition': condition,
    };
  }

  ReturnRequestItemModel copyWith({
    String? id,
    String? returnRequestId,
    String? orderId,
    int? itemIndex,
    String? productId,
    String? productName,
    String? bucketSize,
    double? unitPrice,
    String? colorName,
    String? colorHex,
    int? quantity,
    String? reason,
    String? condition,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReturnRequestItemModel(
      id: id ?? this.id,
      returnRequestId: returnRequestId ?? this.returnRequestId,
      orderId: orderId ?? this.orderId,
      itemIndex: itemIndex ?? this.itemIndex,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      bucketSize: bucketSize ?? this.bucketSize,
      unitPrice: unitPrice ?? this.unitPrice,
      colorName: colorName ?? this.colorName,
      colorHex: colorHex ?? this.colorHex,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      condition: condition ?? this.condition,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// ReturnRequestModel
// ---------------------------------------------------------------------------
class ReturnRequestModel {
  final String id;
  final String orderId;
  final String userId;
  final ReturnStatus status;
  final String reason;
  final String? description;
  final String? adminNote;
  final double refundAmount;
  final String refundMethod;
  final String? billUrl;
  final List<ReturnRequestItemModel> items;

  // Lifecycle timestamps
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? pickupScheduledAt;
  final DateTime? pickedUpAt;
  final DateTime? receivedAt;
  final DateTime? refundProcessingAt;
  final DateTime? refundedAt;
  final DateTime? rejectedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ReturnRequestModel({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.status,
    required this.reason,
    this.description,
    this.adminNote,
    required this.refundAmount,
    this.refundMethod = 'original_payment',
    this.billUrl,
    this.items = const [],
    required this.requestedAt,
    this.approvedAt,
    this.pickupScheduledAt,
    this.pickedUpAt,
    this.receivedAt,
    this.refundProcessingAt,
    this.refundedAt,
    this.rejectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Short display ID, e.g. "RET-1A2B3C4D"
  String get displayId => 'RET-${id.substring(0, 8).toUpperCase()}';

  /// Clean admin note without metadata tags
  String? get cleanAdminNote {
    if (adminNote == null) return null;
    final clean = adminNote!.replaceAll(RegExp(r'\[RETURN_BILL_URL:[^\]]+\]'), '').trim();
    return clean.isEmpty ? null : clean;
  }

  /// Computed estimated refund from items (client-side for display).
  double get computedRefundAmount =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  static String? _extractBillUrl(dynamic note) {
    if (note == null || note is! String) return null;
    final m = RegExp(r'\[RETURN_BILL_URL:([^\]]+)\]').firstMatch(note);
    return m?.group(1);
  }

  factory ReturnRequestModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['return_request_items'] as List<dynamic>?)
            ?.map((e) =>
                ReturnRequestItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ReturnRequestModel(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      userId: json['user_id'] ?? '',
      status: ReturnStatus.fromString(json['status'] ?? 'requested'),
      reason: json['reason'] ?? '',
      description: json['description'],
      adminNote: json['admin_note'],
      refundAmount: (json['refund_amount'] ?? 0).toDouble(),
      refundMethod: json['refund_method'] ?? 'original_payment',
      billUrl: json['bill_url'] ?? _extractBillUrl(json['admin_note']),
      items: itemsList,
      requestedAt:
          DateTime.tryParse(json['requested_at'] ?? '') ?? DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'])
          : null,
      pickupScheduledAt: json['pickup_scheduled_at'] != null
          ? DateTime.tryParse(json['pickup_scheduled_at'])
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.tryParse(json['picked_up_at'])
          : null,
      receivedAt: json['received_at'] != null
          ? DateTime.tryParse(json['received_at'])
          : null,
      refundProcessingAt: json['refund_processing_at'] != null
          ? DateTime.tryParse(json['refund_processing_at'])
          : null,
      refundedAt: json['refunded_at'] != null
          ? DateTime.tryParse(json['refunded_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'])
          : null,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'status': status.value,
      'reason': reason,
      'description': description,
      'admin_note': adminNote,
      'refund_amount': refundAmount,
      'refund_method': refundMethod,
      if (billUrl != null) 'bill_url': billUrl,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'pickup_scheduled_at': pickupScheduledAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'refund_processing_at': refundProcessingAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReturnRequestModel copyWith({
    String? id,
    String? orderId,
    String? userId,
    ReturnStatus? status,
    String? reason,
    String? description,
    String? adminNote,
    double? refundAmount,
    String? refundMethod,
    String? billUrl,
    List<ReturnRequestItemModel>? items,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? pickupScheduledAt,
    DateTime? pickedUpAt,
    DateTime? receivedAt,
    DateTime? refundProcessingAt,
    DateTime? refundedAt,
    DateTime? rejectedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReturnRequestModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      adminNote: adminNote ?? this.adminNote,
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      billUrl: billUrl ?? this.billUrl,
      items: items ?? this.items,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      pickupScheduledAt: pickupScheduledAt ?? this.pickupScheduledAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      receivedAt: receivedAt ?? this.receivedAt,
      refundProcessingAt: refundProcessingAt ?? this.refundProcessingAt,
      refundedAt: refundedAt ?? this.refundedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
