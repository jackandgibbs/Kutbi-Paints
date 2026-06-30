class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String pin;
  final String role; // 'admin' or 'painter'
  final String status; // 'active', 'inactive', 'suspended'
  final String? businessName;
  final String? businessAddress;
  final int points;
  final String tier; // 'gold', 'silver'
  final double totalPurchaseValue;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? referralCode;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.pin,
    required this.role,
    required this.status,
    this.businessName,
    this.businessAddress,
    this.points = 0,
    this.tier = 'silver',
    this.totalPurchaseValue = 0,
    this.appVersion,
    required this.createdAt,
    required this.updatedAt,
    this.referralCode,
  });

  bool get isAdmin => role == 'admin';
  bool get isPainter => role == 'painter';
  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';
  bool get isSuspended => status == 'suspended';
  bool get isGold => tier == 'gold';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      pin: json['pin'] ?? '',
      role: json['role'] ?? 'painter',
      status: json['status'] ?? 'inactive',
      businessName: json['business_name'],
      businessAddress: json['business_address'],
      points: (json['points'] ?? 0).toInt(),
      tier: json['tier'] ?? 'silver',
      totalPurchaseValue:
          (json['total_purchase_value'] ?? 0).toDouble(),
      appVersion: json['app_version'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      referralCode: json['referral_code'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'pin': pin,
      'role': role,
      'status': status,
      'business_name': businessName,
      'business_address': businessAddress,
      'points': points,
      'tier': tier,
      'total_purchase_value': totalPurchaseValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'referral_code': referralCode,
    };
    if (appVersion != null) {
      map['app_version'] = appVersion;
    }
    return map;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? pin,
    String? role,
    String? status,
    String? businessName,
    String? businessAddress,
    int? points,
    String? tier,
    double? totalPurchaseValue,
    String? appVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? referralCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      status: status ?? this.status,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      points: points ?? this.points,
      tier: tier ?? this.tier,
      totalPurchaseValue: totalPurchaseValue ?? this.totalPurchaseValue,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      referralCode: referralCode ?? this.referralCode,
    );
  }
}
