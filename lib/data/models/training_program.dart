enum ProgressionSchemeType {
  doubleProgression,
  linearWeight,
  fixedLoad,
  linearPeriodization,
  periodized,
}

enum DayKind { training, rest }

enum AdvanceMode { auto, manual }

ProgressionSchemeType _progressionSchemeTypeFromString(String? value) {
  switch (value) {
    case 'doubleProgression':
      return ProgressionSchemeType.doubleProgression;
    case 'linearWeight':
      return ProgressionSchemeType.linearWeight;
    case 'fixedLoad':
      return ProgressionSchemeType.fixedLoad;
    case 'linearPeriodization':
      return ProgressionSchemeType.linearPeriodization;
    case 'periodized':
      return ProgressionSchemeType.periodized;
    default:
      return ProgressionSchemeType.doubleProgression;
  }
}

DayKind _dayKindFromString(String? value) {
  switch (value) {
    case 'training':
      return DayKind.training;
    case 'rest':
      return DayKind.rest;
    default:
      return DayKind.training;
  }
}

AdvanceMode _advanceModeFromString(String? value) {
  switch (value) {
    case 'auto':
      return AdvanceMode.auto;
    case 'manual':
      return AdvanceMode.manual;
    default:
      return AdvanceMode.auto;
  }
}

class ProgressionScheme {
  final ProgressionSchemeType type;
  final double weightIncrementKg;
  final double percentIncrement;
  final int periodWeeks;
  final double deloadPercent;

  const ProgressionScheme({
    this.type = ProgressionSchemeType.doubleProgression,
    this.weightIncrementKg = 2.5,
    this.percentIncrement = 5.0,
    this.periodWeeks = 4,
    this.deloadPercent = 0.5,
  });

  factory ProgressionScheme.fromJson(Map<String, dynamic> json) =>
      ProgressionScheme(
        type: _progressionSchemeTypeFromString(json['type'] as String?),
        weightIncrementKg:
            (json['weightIncrementKg'] as num?)?.toDouble() ?? 2.5,
        percentIncrement: (json['percentIncrement'] as num?)?.toDouble() ?? 5.0,
        periodWeeks: json['periodWeeks'] as int? ?? 4,
        deloadPercent: (json['deloadPercent'] as num?)?.toDouble() ?? 0.5,
      );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'weightIncrementKg': weightIncrementKg,
    'percentIncrement': percentIncrement,
    'periodWeeks': periodWeeks,
    'deloadPercent': deloadPercent,
  };

  ProgressionScheme copyWith({
    ProgressionSchemeType? type,
    double? weightIncrementKg,
    double? percentIncrement,
    int? periodWeeks,
    double? deloadPercent,
  }) => ProgressionScheme(
    type: type ?? this.type,
    weightIncrementKg: weightIncrementKg ?? this.weightIncrementKg,
    percentIncrement: percentIncrement ?? this.percentIncrement,
    periodWeeks: periodWeeks ?? this.periodWeeks,
    deloadPercent: deloadPercent ?? this.deloadPercent,
  );
}

class ProgramExercise {
  final String id;
  final String exerciseId;
  final int targetSets;
  final int minReps;
  final int maxReps;
  final double startingWeightKg;
  final ProgressionScheme progressionScheme;
  final int sortOrder;

  const ProgramExercise({
    required this.id,
    required this.exerciseId,
    this.targetSets = 3,
    this.minReps = 8,
    this.maxReps = 12,
    this.startingWeightKg = 0,
    this.progressionScheme = const ProgressionScheme(),
    this.sortOrder = 0,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> json) =>
      ProgramExercise(
        id: json['id'] as String,
        exerciseId: json['exerciseId'] as String,
        targetSets: json['targetSets'] as int? ?? 3,
        minReps: json['minReps'] as int? ?? 8,
        maxReps: json['maxReps'] as int? ?? 12,
        startingWeightKg: (json['startingWeightKg'] as num?)?.toDouble() ?? 0,
        progressionScheme: json['progressionScheme'] != null
            ? ProgressionScheme.fromJson(
                json['progressionScheme'] as Map<String, dynamic>,
              )
            : const ProgressionScheme(),
        sortOrder: json['sortOrder'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'targetSets': targetSets,
    'minReps': minReps,
    'maxReps': maxReps,
    'startingWeightKg': startingWeightKg,
    'progressionScheme': progressionScheme.toJson(),
    'sortOrder': sortOrder,
  };

  ProgramExercise copyWith({
    String? id,
    String? exerciseId,
    int? targetSets,
    int? minReps,
    int? maxReps,
    double? startingWeightKg,
    ProgressionScheme? progressionScheme,
    int? sortOrder,
  }) => ProgramExercise(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    targetSets: targetSets ?? this.targetSets,
    minReps: minReps ?? this.minReps,
    maxReps: maxReps ?? this.maxReps,
    startingWeightKg: startingWeightKg ?? this.startingWeightKg,
    progressionScheme: progressionScheme ?? this.progressionScheme,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

class ProgramDay {
  final String id;
  final String name;
  final DayKind kind;
  final List<ProgramExercise> exercises;

  const ProgramDay({
    required this.id,
    required this.name,
    this.kind = DayKind.training,
    this.exercises = const [],
  });

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    kind: _dayKindFromString(json['kind'] as String?),
    exercises: json['exercises'] != null
        ? (json['exercises'] as List)
              .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
              .toList()
        : const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  ProgramDay copyWith({
    String? id,
    String? name,
    DayKind? kind,
    List<ProgramExercise>? exercises,
  }) => ProgramDay(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    exercises: exercises ?? this.exercises,
  );
}

class TrainingProgram {
  final String id;
  final String userId;
  final String name;
  final List<ProgramDay> days;
  final bool active;
  final int currentDayIndex;
  final AdvanceMode advanceMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingProgram({
    required this.id,
    required this.userId,
    required this.name,
    this.days = const [],
    this.active = false,
    this.currentDayIndex = 0,
    this.advanceMode = AdvanceMode.auto,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingProgram.fromJson(Map<String, dynamic> json) =>
      TrainingProgram(
        id: json['id'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String? ?? '',
        days: json['days'] != null
            ? (json['days'] as List)
                  .map((d) => ProgramDay.fromJson(d as Map<String, dynamic>))
                  .toList()
            : const [],
        active: json['active'] as bool? ?? false,
        currentDayIndex: json['currentDayIndex'] as int? ?? 0,
        advanceMode: _advanceModeFromString(json['advanceMode'] as String?),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'name': name,
    'days': days.map((d) => d.toJson()).toList(),
    'active': active,
    'currentDayIndex': currentDayIndex,
    'advanceMode': advanceMode.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  int get normalizedCurrentDayIndex {
    if (days.isEmpty) return 0;
    return currentDayIndex % days.length;
  }

  ProgramDay? get currentDay {
    if (days.isEmpty) return null;
    return days[normalizedCurrentDayIndex];
  }

  TrainingProgram advanceToNextDay({DateTime? advancedAt}) {
    final nextIndex = days.isEmpty
        ? 0
        : (normalizedCurrentDayIndex + 1) % days.length;
    return copyWith(
      currentDayIndex: nextIndex,
      updatedAt: advancedAt ?? DateTime.now(),
    );
  }

  TrainingProgram removeDayAt(int index, {DateTime? removedAt}) {
    if (index < 0 || index >= days.length) return this;

    final nextDays = [...days]..removeAt(index);
    final normalized = normalizedCurrentDayIndex;
    var nextIndex = 0;
    if (nextDays.isNotEmpty) {
      if (index < normalized) {
        nextIndex = normalized - 1;
      } else {
        nextIndex = normalized.clamp(0, nextDays.length - 1).toInt();
      }
    }

    return copyWith(
      days: nextDays,
      currentDayIndex: nextIndex,
      updatedAt: removedAt ?? DateTime.now(),
    );
  }

  TrainingProgram copyWith({
    String? id,
    String? userId,
    String? name,
    List<ProgramDay>? days,
    bool? active,
    int? currentDayIndex,
    AdvanceMode? advanceMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TrainingProgram(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    days: days ?? this.days,
    active: active ?? this.active,
    currentDayIndex: currentDayIndex ?? this.currentDayIndex,
    advanceMode: advanceMode ?? this.advanceMode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

TrainingProgram? activeTrainingProgramForUser(
  List<TrainingProgram> programs,
  String userId,
) {
  for (final program in programs) {
    if (program.active && program.userId == userId) return program;
  }
  return null;
}

class WorkoutPrescription {
  final String programId;
  final String programDayId;
  final String programExerciseId;
  final String exerciseId;
  final int sets;
  final int reps;
  final double weightKg;
  final String reason;

  const WorkoutPrescription({
    required this.programId,
    required this.programDayId,
    required this.programExerciseId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.reason = '',
  });

  factory WorkoutPrescription.fromJson(Map<String, dynamic> json) =>
      WorkoutPrescription(
        programId: json['programId'] as String,
        programDayId: json['programDayId'] as String,
        programExerciseId: json['programExerciseId'] as String,
        exerciseId: json['exerciseId'] as String,
        sets: json['sets'] as int,
        reps: json['reps'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        reason: json['reason'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'programId': programId,
    'programDayId': programDayId,
    'programExerciseId': programExerciseId,
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': reps,
    'weightKg': weightKg,
    'reason': reason,
  };
}

/// Returns true when all required [ProgramExercise.id]s in [currentDay] are
/// present in [savedProgramExerciseIds] and [currentDay] is a training day
/// with at least one exercise.
bool shouldAdvanceProgram({
  required ProgramDay? currentDay,
  required Set<String> savedProgramExerciseIds,
  AdvanceMode advanceMode = AdvanceMode.auto,
  bool selectedDateIsToday = true,
}) {
  if (advanceMode != AdvanceMode.auto) return false;
  if (!selectedDateIsToday) return false;
  if (currentDay == null) return false;
  if (currentDay.kind != DayKind.training) return false;
  if (currentDay.exercises.isEmpty) return false;
  if (savedProgramExerciseIds.isEmpty) return false;
  final requiredIds = currentDay.exercises.map((e) => e.id).toSet();
  return requiredIds.every((id) => savedProgramExerciseIds.contains(id));
}

class WorkoutSetLog {
  final String id;
  final String workoutLogId;
  final String programId;
  final String programExerciseId;
  final int setIndex;
  final int reps;
  final double weightKg;
  final bool completed;

  const WorkoutSetLog({
    required this.id,
    required this.workoutLogId,
    required this.programId,
    required this.programExerciseId,
    required this.setIndex,
    required this.reps,
    required this.weightKg,
    this.completed = false,
  });

  factory WorkoutSetLog.fromJson(Map<String, dynamic> json) => WorkoutSetLog(
    id: json['id'] as String,
    workoutLogId: json['workoutLogId'] as String,
    programId: json['programId'] as String,
    programExerciseId: json['programExerciseId'] as String,
    setIndex: json['setIndex'] as int,
    reps: json['reps'] as int,
    weightKg: (json['weightKg'] as num).toDouble(),
    completed: json['completed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutLogId': workoutLogId,
    'programId': programId,
    'programExerciseId': programExerciseId,
    'setIndex': setIndex,
    'reps': reps,
    'weightKg': weightKg,
    'completed': completed,
  };

  WorkoutSetLog copyWith({
    String? id,
    String? workoutLogId,
    String? programId,
    String? programExerciseId,
    int? setIndex,
    int? reps,
    double? weightKg,
    bool? completed,
  }) => WorkoutSetLog(
    id: id ?? this.id,
    workoutLogId: workoutLogId ?? this.workoutLogId,
    programId: programId ?? this.programId,
    programExerciseId: programExerciseId ?? this.programExerciseId,
    setIndex: setIndex ?? this.setIndex,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    completed: completed ?? this.completed,
  );
}
