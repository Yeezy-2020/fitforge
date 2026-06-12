class BodyMeasurement {
  final String id;
  final String userId;
  final DateTime date;
  final double? weight;
  final double? neck;
  final double? shoulders;
  final double? chest;
  final double? leftArm;
  final double? rightArm;
  final double? waist;
  final double? hips;
  final double? leftThigh;
  final double? rightThigh;

  const BodyMeasurement({required this.id, required this.userId, required this.date,
    this.weight, this.neck, this.shoulders, this.chest, this.leftArm, this.rightArm,
    this.waist, this.hips, this.leftThigh, this.rightThigh});

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) => BodyMeasurement(
    id: json['id'] as String, userId: json['userId'] as String, date: DateTime.parse(json['date'] as String),
    weight: (json['weight'] as num?)?.toDouble(), neck: (json['neck'] as num?)?.toDouble(),
    shoulders: (json['shoulders'] as num?)?.toDouble(), chest: (json['chest'] as num?)?.toDouble(),
    leftArm: (json['leftArm'] as num?)?.toDouble(), rightArm: (json['rightArm'] as num?)?.toDouble(),
    waist: (json['waist'] as num?)?.toDouble(), hips: (json['hips'] as num?)?.toDouble(),
    leftThigh: (json['leftThigh'] as num?)?.toDouble(), rightThigh: (json['rightThigh'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'userId': userId, 'date': date.toIso8601String(),
    if (weight != null) 'weight': weight, if (neck != null) 'neck': neck,
    if (shoulders != null) 'shoulders': shoulders, if (chest != null) 'chest': chest,
    if (leftArm != null) 'leftArm': leftArm, if (rightArm != null) 'rightArm': rightArm,
    if (waist != null) 'waist': waist, if (hips != null) 'hips': hips,
    if (leftThigh != null) 'leftThigh': leftThigh, if (rightThigh != null) 'rightThigh': rightThigh,
  };
}
