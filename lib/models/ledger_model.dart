class LedgerEntry {
  final String id;
  final String painterId;
  final String? orderId;
  final String type; // 'credit' (painter owes) or 'payment' (painter paid)
  final double amount;
  final double runningBalance;
  final String? note;
  final String? createdBy;
  final DateTime createdAt;

  LedgerEntry({
    required this.id,
    required this.painterId,
    this.orderId,
    required this.type,
    required this.amount,
    this.runningBalance = 0,
    this.note,
    this.createdBy,
    required this.createdAt,
  });

  bool get isCredit => type == 'credit';
  bool get isPayment => type == 'payment';

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'] ?? '',
      painterId: json['painter_id'] ?? '',
      orderId: json['order_id'],
      type: json['type'] ?? 'credit',
      amount: (json['amount'] ?? 0).toDouble(),
      runningBalance: (json['running_balance'] ?? 0).toDouble(),
      note: json['note'],
      createdBy: json['created_by'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'painter_id': painterId,
      'order_id': orderId,
      'type': type,
      'amount': amount,
      'running_balance': runningBalance,
      'note': note,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
