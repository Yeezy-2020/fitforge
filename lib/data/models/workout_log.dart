class WorkoutLog {
  final String id;
  final String userId;
  final String exerciseId;
  final DateTime date;
  final int sets;
  final int reps;
  final double weightKg;
  final String? note;
  final DateTime? createdAt;

  const WorkoutLog({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.date,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.note,
    this.createdAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    userId: json['userId'] as String,
    exerciseId: json['exerciseId'] as String,
    date: DateTime.parse(json['date'] as String),
    sets: json['sets'] as int,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
    note: json['note'] as String?,
    createdAt:
        json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'exerciseId': exerciseId,
    'date': date.toIso8601String(),
    'sets': sets,
    'reps': reps,
    'weightKg': weightKg,
    if (note != null) 'note': note,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
