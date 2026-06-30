class QRCodeModel {
  final String id;
  final String batchId;
  final String qrValue;
  final int points;
  final String colorScheme;
  final String status; // active, used, expired, archived
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedBy;
  final String? usedByName;
  final int quantity;
  final String? message;
  final String? createdBy;
  final String? customLogoBase64;
  final int scans;

  const QRCodeModel({
    required this.id,
    required this.batchId,
    required this.qrValue,
    required this.points,
    required this.colorScheme,
    required this.status,
    required this.createdAt,
    this.usedAt,
    this.usedBy,
    this.usedByName,
    required this.quantity,
    this.message,
    this.createdBy,
    this.customLogoBase64,
    this.scans = 0,
  });

  bool get isRedeemed => status == 'used';
  bool get isActive => status == 'active';

  QRCodeModel copyWith({
    String? id,
    String? batchId,
    String? qrValue,
    int? points,
    String? colorScheme,
    String? status,
    DateTime? createdAt,
    DateTime? usedAt,
    String? usedBy,
    String? usedByName,
    int? quantity,
    String? message,
    String? createdBy,
    String? customLogoBase64,
    int? scans,
  }) {
    return QRCodeModel(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      qrValue: qrValue ?? this.qrValue,
      points: points ?? this.points,
      colorScheme: colorScheme ?? this.colorScheme,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      usedAt: usedAt ?? this.usedAt,
      usedBy: usedBy ?? this.usedBy,
      usedByName: usedByName ?? this.usedByName,
      quantity: quantity ?? this.quantity,
      message: message ?? this.message,
      createdBy: createdBy ?? this.createdBy,
      customLogoBase64: customLogoBase64 ?? this.customLogoBase64,
      scans: scans ?? this.scans,
    );
  }

  factory QRCodeModel.fromJson(Map<String, dynamic> json) {
    return QRCodeModel(
      id: json['id'] as String? ?? '',
      batchId: json['batch_id'] as String? ?? json['id'] as String? ?? '',
      qrValue: json['qr_value'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      colorScheme: json['color_scheme'] as String? ?? 'teal',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      usedAt: json['used_at'] != null
          ? DateTime.tryParse(json['used_at'] as String)
          : null,
      usedBy: json['used_by'] as String?,
      usedByName: json['used_by_name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      message: json['message'] as String?,
      createdBy: json['created_by'] as String?,
      customLogoBase64: json['custom_logo_base64'] as String?,
      scans: (json['scans'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'qr_value': qrValue,
      'points': points,
      'color_scheme': colorScheme,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'used_by': usedBy,
      'used_by_name': usedByName,
      'quantity': quantity,
      'message': message,
      'created_by': createdBy,
      'custom_logo_base64': customLogoBase64,
      'scans': scans,
    };
  }
}
