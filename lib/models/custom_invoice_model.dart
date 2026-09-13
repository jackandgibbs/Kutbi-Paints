import 'order_model.dart';

class CustomInvoiceItem {
  final String productName;
  final String bucketSize;
  final int quantity;
  final double rate;
  final double amount;
  final String? shade;

  CustomInvoiceItem({
    required this.productName,
    required this.bucketSize,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.shade,
  });

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'bucketSize': bucketSize,
        'quantity': quantity,
        'rate': rate,
        'amount': amount,
        'shade': shade,
      };

  factory CustomInvoiceItem.fromJson(Map<String, dynamic> json) => CustomInvoiceItem(
        productName: (json['productName'] ?? json['name'] ?? 'Item').toString(),
        bucketSize: (json['bucketSize'] ?? json['size'] ?? '').toString(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        shade: json['shade']?.toString(),
      );

  CustomInvoiceItem copyWith({
    String? productName,
    String? bucketSize,
    int? quantity,
    double? rate,
    double? amount,
    String? shade,
  }) {
    return CustomInvoiceItem(
      productName: productName ?? this.productName,
      bucketSize: bucketSize ?? this.bucketSize,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      shade: shade ?? this.shade,
    );
  }
}

class CustomInvoiceModel {
  final String id;
  final String invoiceNumber;
  final String billType; // 'purchase' or 'return'
  final String? painterId;
  final String painterName;
  final String painterPhone;
  final DateTime date;
  final List<CustomInvoiceItem> items;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final String notes;
  final DateTime createdAt;
  final String? orderId;
  final String? orderStatus; // 'accepted', 'preparing', 'dispatched', 'delivered'

  CustomInvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.billType,
    this.painterId,
    required this.painterName,
    required this.painterPhone,
    required this.date,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.totalAmount,
    this.notes = '',
    required this.createdAt,
    this.orderId,
    this.orderStatus,
  });

  bool get isPurchase => billType.toLowerCase() == 'purchase';
  bool get isReturn => billType.toLowerCase() == 'return';

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'billType': billType,
        'painterId': painterId,
        'painterName': painterName,
        'painterPhone': painterPhone,
        'date': date.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'totalAmount': totalAmount,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'orderId': orderId,
        'orderStatus': orderStatus,
      };

  factory CustomInvoiceModel.fromJson(Map<String, dynamic> json) => CustomInvoiceModel(
        id: json['id'] as String,
        invoiceNumber: (json['invoiceNumber'] ?? 'INV-001').toString(),
        billType: (json['billType'] ?? 'purchase').toString(),
        painterId: json['painterId'] as String?,
        painterName: (json['painterName'] ?? '').toString(),
        painterPhone: (json['painterPhone'] ?? '').toString(),
        date: json['date'] != null
            ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => CustomInvoiceItem.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        notes: (json['notes'] ?? '').toString(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        orderId: json['orderId'] as String?,
        orderStatus: json['orderStatus'] as String?,
      );

  factory CustomInvoiceModel.fromOrder(OrderModel order) {
    String invoiceNumber = order.siteLocation.startsWith('Invoice #')
        ? order.siteLocation.replaceFirst('Invoice #', '')
        : 'INV-${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}';

    return CustomInvoiceModel(
      id: order.id,
      invoiceNumber: invoiceNumber,
      billType: order.status == 'returned' ? 'return' : 'purchase',
      painterId: order.painterId,
      painterName: order.painterName ?? '',
      painterPhone: order.painterPhone ?? '',
      date: order.createdAt,
      items: order.items.map((it) => CustomInvoiceItem(
        productName: it.productName,
        bucketSize: it.bucketSize,
        shade: it.shadeCode,
        quantity: it.quantity,
        rate: it.unitPrice,
        amount: it.totalPrice,
      )).toList(),
      subtotal: order.subtotal > 0 ? order.subtotal : order.totalAmount + order.discountAmount,
      discount: order.discountAmount,
      totalAmount: order.totalAmount,
      notes: '',
      orderId: order.id,
      orderStatus: order.status,
      createdAt: order.createdAt,
    );
  }

  CustomInvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
    String? billType,
    String? painterId,
    String? painterName,
    String? painterPhone,
    DateTime? date,
    List<CustomInvoiceItem>? items,
    double? subtotal,
    double? discount,
    double? totalAmount,
    String? notes,
    DateTime? createdAt,
    String? orderId,
    String? orderStatus,
  }) {
    return CustomInvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      billType: billType ?? this.billType,
      painterId: painterId ?? this.painterId,
      painterName: painterName ?? this.painterName,
      painterPhone: painterPhone ?? this.painterPhone,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      orderStatus: orderStatus ?? this.orderStatus,
    );
  }
}
