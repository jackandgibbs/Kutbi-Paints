class PointsHistoryModel {
  final String id;
  final String month; // e.g., "March-26"
  final DateTime resetDate;
  final List<PainterPointsSnapshot> painters;

  PointsHistoryModel({
    required this.id,
    required this.month,
    required this.resetDate,
    required this.painters,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'reset_date': resetDate.toIso8601String(),
    'painters': painters.map((p) => p.toJson()).toList(),
  };

  factory PointsHistoryModel.fromJson(Map<String, dynamic> json) => PointsHistoryModel(
    id: json['id'] as String,
    month: json['month'] as String,
    resetDate: DateTime.parse(json['reset_date'] as String),
    painters: (json['painters'] as List).map((p) => PainterPointsSnapshot.fromJson(p)).toList(),
  );
}

class PainterPointsSnapshot {
  final String painterId;
  final String name;
  final String phone;
  final int points;

  PainterPointsSnapshot({
    required this.painterId,
    required this.name,
    required this.phone,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
    'painter_id': painterId,
    'name': name,
    'phone': phone,
    'points': points,
  };

  factory PainterPointsSnapshot.fromJson(Map<String, dynamic> json) => PainterPointsSnapshot(
    painterId: json['painter_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    points: json['points'] as int,
  );
}
