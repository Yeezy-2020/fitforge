class WorkoutLog {
  final String id;
  final String userId;
  final String exerciseId;
  final String? programId;
  final String? programDayId;
  final String? programExerciseId;
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
    this.programId,
    this.programDayId,
    this.programExerciseId,
    required this.date,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.note,
    this.createdAt,
  }) : assert(
         (programId == null &&
                 programDayId == null &&
                 programExerciseId == null) ||
             (programId != null &&
                 programDayId != null &&
                 programExerciseId != null),
         'Program slot identifiers must be all null or all non-null.',
       );

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    final programId = json['programId'] as String?;
    final programDayId = json['programDayId'] as String?;
    final programExerciseId = json['programExerciseId'] as String?;
    if (!_isValidProgramSlot(programId, programDayId, programExerciseId)) {
      throw const FormatException(
        'WorkoutLog program slot identifiers must be all null or all non-null.',
      );
    }

    return WorkoutLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      exerciseId: json['exerciseId'] as String,
      programId: programId,
      programDayId: programDayId,
      programExerciseId: programExerciseId,
      date: DateTime.parse(json['date'] as String),
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weightKg: (json['weightKg'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  bool get hasProgramSlot =>
      programId != null && programDayId != null && programExerciseId != null;

  Map<String, dynamic> toJson() {
    if (!_isValidProgramSlot(programId, programDayId, programExerciseId)) {
      throw const FormatException(
        'WorkoutLog program slot identifiers must be all null or all non-null.',
      );
    }

    return {
      'id': id,
      'userId': userId,
      'exerciseId': exerciseId,
      if (programId != null) 'programId': programId,
      if (programDayId != null) 'programDayId': programDayId,
      if (programExerciseId != null) 'programExerciseId': programExerciseId,
      'date': date.toIso8601String(),
      'sets': sets,
      'reps': reps,
      'weightKg': weightKg,
      if (note != null) 'note': note,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

bool _isValidProgramSlot(
  String? programId,
  String? programDayId,
  String? programExerciseId,
) {
  final presentCount = [
    programId,
    programDayId,
    programExerciseId,
  ].where((value) => value != null).length;
  return presentCount == 0 || presentCount == 3;
}
