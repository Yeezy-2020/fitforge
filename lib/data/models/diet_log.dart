enum MealType { breakfast, morningSnack, lunch, afternoonSnack, dinner, eveningSnack }

class DietLog {
  final String id;
  final String userId;
  final String foodId;
  final DateTime date;
  final MealType mealType;
  final double grams;
  final double calories;
  final DateTime? createdAt;

  const DietLog({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.date,
    required this.mealType,
    required this.grams,
    required this.calories,
    this.createdAt,
  });

  factory DietLog.fromJson(Map<String, dynamic> json) => DietLog(
    id: json['id'] as String,
    userId: json['userId'] as String,
    foodId: json['foodId'] as String,
    date: DateTime.parse(json['date'] as String),
    mealType: MealType.values.firstWhere(
      (e) => e.name == json['mealType'],
      orElse: () => MealType.lunch,
    ),
    grams: (json['grams'] as num).toDouble(),
    calories: (json['calories'] as num).toDouble(),
    createdAt:
        json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'foodId': foodId,
    'date': date.toIso8601String(),
    'mealType': mealType.name,
    'grams': grams,
    'calories': calories,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
