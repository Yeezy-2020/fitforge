enum ProgressionSchemeType {
  doubleProgression,
  linearWeight,
  fixedLoad,
  linearPeriodization,
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
      return ProgressionSchemeType.fixedLoad;
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
    this.percentIncrement = 2.5,
    this.periodWeeks = 4,
    this.deloadPercent = 0.5,
  });

  factory ProgressionScheme.fromJson(Map<String, dynamic> json) =>
      ProgressionScheme(
        type: _progressionSchemeTypeFromString(json['type'] as String?),
        weightIncrementKg:
            (json['weightIncrementKg'] as num?)?.toDouble() ?? 2.5,
        percentIncrement: (json['percentIncrement'] as num?)?.toDouble() ?? 2.5,
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

class ProgramPausePeriod {
  final DateTime startDate;
  final DateTime? endDate;
  final bool extendEndDate;

  ProgramPausePeriod({
    required DateTime startDate,
    DateTime? endDate,
    this.extendEndDate = true,
  }) : startDate = _dateOnly(startDate),
       endDate = endDate == null ? null : _dateOnly(endDate);

  factory ProgramPausePeriod.fromJson(Map<String, dynamic> json) =>
      ProgramPausePeriod(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        extendEndDate: json['extendEndDate'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'startDate': _dateOnly(startDate).toIso8601String(),
    'endDate': endDate == null ? null : _dateOnly(endDate!).toIso8601String(),
    'extendEndDate': extendEndDate,
  };

  bool contains(DateTime date) {
    final target = _dateOnly(date);
    final start = _dateOnly(startDate);
    final end = endDate == null ? null : _dateOnly(endDate!);
    if (target.isBefore(start)) return false;
    return end == null || target.isBefore(end);
  }

  int pausedDaysBefore(DateTime date) {
    final target = _dateOnly(date);
    final start = startDate;
    if (!target.isAfter(start)) return 0;
    final rawEnd = endDate == null ? target : endDate!;
    final cappedEnd = rawEnd.isAfter(target) ? target : rawEnd;
    if (!cappedEnd.isAfter(start)) return 0;
    return cappedEnd.difference(start).inDays;
  }

  ProgramPausePeriod copyWith({
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? extendEndDate,
  }) => ProgramPausePeriod(
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    extendEndDate: extendEndDate ?? this.extendEndDate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgramPausePeriod &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          extendEndDate == other.extendEndDate;

  @override
  int get hashCode => Object.hash(startDate, endDate, extendEndDate);
}

typedef PausePeriod = ProgramPausePeriod;

class TrainingProgram {
  final String id;
  final String userId;
  final String name;
  final List<ProgramDay> days;
  final bool active;
  final int currentDayIndex;
  final DateTime? activatedAt;
  final int activatedDayIndex;
  final int? plannedCycleCount;
  final AdvanceMode advanceMode;
  final List<ProgramPausePeriod> pausePeriods;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingProgram({
    required this.id,
    required this.userId,
    required this.name,
    this.days = const [],
    this.active = false,
    this.currentDayIndex = 0,
    this.activatedAt,
    this.activatedDayIndex = 0,
    this.plannedCycleCount,
    this.advanceMode = AdvanceMode.auto,
    this.pausePeriods = const [],
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
        activatedAt: json['activatedAt'] != null
            ? DateTime.parse(json['activatedAt'] as String)
            : null,
        activatedDayIndex: json['activatedDayIndex'] as int? ?? 0,
        plannedCycleCount: json['plannedCycleCount'] as int?,
        advanceMode: _advanceModeFromString(json['advanceMode'] as String?),
        pausePeriods: json['pausePeriods'] != null
            ? (json['pausePeriods'] as List)
                  .map(
                    (p) =>
                        ProgramPausePeriod.fromJson(p as Map<String, dynamic>),
                  )
                  .toList()
            : const [],
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
    'activatedAt': activatedAt?.toIso8601String(),
    'activatedDayIndex': activatedDayIndex,
    'plannedCycleCount': plannedCycleCount,
    'advanceMode': advanceMode.name,
    'pausePeriods': pausePeriods.map((p) => p.toJson()).toList(),
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

  int? get plannedProgramDayCount {
    final cycles = plannedCycleCount;
    if (cycles == null || cycles <= 0 || days.isEmpty) return null;
    return days.length * cycles;
  }

  int get normalizedActivatedDayIndex {
    if (days.isEmpty) return 0;
    return activatedDayIndex % days.length;
  }

  ProgramDay? programDayForDate(DateTime date) {
    if (!active || days.isEmpty) return null;
    final startIndex = activatedAt == null
        ? normalizedCurrentDayIndex
        : normalizedActivatedDayIndex;
    final activeOffset = _activeOffsetForDate(date);
    if (activeOffset == null) return null;
    final index = (startIndex + activeOffset) % days.length;
    return days[index];
  }

  ProgramDay? programDayForWorkoutDate(DateTime date, {DateTime? today}) {
    if (!active || days.isEmpty) return null;
    final target = _dateOnly(date);
    final currentDate = _dateOnly(today ?? DateTime.now());
    if (_activeOffsetForDate(target) == null) return null;
    if (target == currentDate) return currentDay;
    return programDayForDate(date);
  }

  DateTime? plannedEndDate() {
    final dayCount = plannedProgramDayCount;
    if (!active || days.isEmpty || dayCount == null) return null;
    if (_mergePausePeriods(
      pausePeriods,
    ).any((period) => period.endDate == null)) {
      return null;
    }

    final start = _dateOnly(activatedAt ?? updatedAt);
    var date = start;
    DateTime? lastScheduledDate;
    var guard = 0;
    while (guard < dayCount + 3650) {
      if (programDayForDate(date) != null) {
        lastScheduledDate = date;
      }
      date = date.add(const Duration(days: 1));
      guard += 1;
    }
    return lastScheduledDate;
  }

  bool isPausedOn(DateTime date) =>
      _mergePausePeriods(pausePeriods).any((period) => period.contains(date));

  bool isPausedNow({DateTime? today}) => isPausedOn(today ?? DateTime.now());

  TrainingProgram pauseFrom(
    DateTime startDate, {
    DateTime? now,
    bool extendEndDate = true,
  }) {
    final programStart = _dateOnly(activatedAt ?? updatedAt);
    final requestedStart = _dateOnly(startDate);
    final effectiveStart = requestedStart.isBefore(programStart)
        ? programStart
        : requestedStart;
    final currentPeriods = _mergePausePeriods(pausePeriods);
    final nextPeriods = _mergePausePeriods([
      ...currentPeriods,
      ProgramPausePeriod(
        startDate: effectiveStart,
        extendEndDate: extendEndDate,
      ),
    ]);
    if (_pausePeriodListsEqual(currentPeriods, nextPeriods)) return this;
    return copyWith(
      pausePeriods: nextPeriods,
      updatedAt: now ?? DateTime.now(),
    );
  }

  TrainingProgram resumeFrom(DateTime resumeDate, {DateTime? now}) {
    final resume = _dateOnly(resumeDate);
    final nextPeriods = <ProgramPausePeriod>[];
    var changed = false;

    for (final period in _mergePausePeriods(pausePeriods)) {
      if (resume.isBefore(period.startDate)) {
        nextPeriods.add(period);
        continue;
      }

      if (resume == period.startDate) {
        changed = true;
        continue;
      }

      final endDate = period.endDate;
      if (endDate == null || resume.isBefore(endDate)) {
        nextPeriods.add(period.copyWith(endDate: resume));
        changed = true;
      } else {
        nextPeriods.add(period);
      }
    }

    if (!changed) return this;
    return copyWith(
      pausePeriods: _mergePausePeriods(nextPeriods),
      updatedAt: now ?? DateTime.now(),
    );
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

  TrainingProgram endExecution({DateTime? endedAt}) => copyWith(
    active: false,
    pausePeriods: const [],
    updatedAt: endedAt ?? DateTime.now(),
  );

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

    final normalizedActivated = normalizedActivatedDayIndex;
    var nextActivatedIndex = 0;
    if (nextDays.isNotEmpty) {
      if (index < normalizedActivated) {
        nextActivatedIndex = normalizedActivated - 1;
      } else {
        nextActivatedIndex = normalizedActivated
            .clamp(0, nextDays.length - 1)
            .toInt();
      }
    }

    return copyWith(
      days: nextDays,
      currentDayIndex: nextIndex,
      activatedDayIndex: nextActivatedIndex,
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
    DateTime? activatedAt,
    int? activatedDayIndex,
    int? plannedCycleCount,
    bool clearPlannedCycleCount = false,
    AdvanceMode? advanceMode,
    List<ProgramPausePeriod>? pausePeriods,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TrainingProgram(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    days: days ?? this.days,
    active: active ?? this.active,
    currentDayIndex: currentDayIndex ?? this.currentDayIndex,
    activatedAt: activatedAt ?? this.activatedAt,
    activatedDayIndex: activatedDayIndex ?? this.activatedDayIndex,
    plannedCycleCount: clearPlannedCycleCount
        ? null
        : plannedCycleCount ?? this.plannedCycleCount,
    advanceMode: advanceMode ?? this.advanceMode,
    pausePeriods: pausePeriods ?? this.pausePeriods,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  int? _activeOffsetForDate(DateTime date) {
    if (!active || days.isEmpty) return null;
    final start = _dateOnly(activatedAt ?? updatedAt);
    final target = _dateOnly(date);
    final offset = target.difference(start).inDays;
    if (offset < 0) return null;
    if (isPausedOn(target)) return null;
    final pausedDays = _extendablePausedDaysBetween(start, target);
    final activeOffset = offset - pausedDays;
    if (activeOffset < 0) return null;
    final plannedDays = plannedProgramDayCount;
    if (plannedDays != null && activeOffset >= plannedDays) return null;
    return activeOffset;
  }

  int _extendablePausedDaysBetween(DateTime start, DateTime target) {
    if (!target.isAfter(start)) return 0;

    var pausedDays = 0;
    for (final period in _mergePausePeriods(pausePeriods)) {
      if (!period.extendEndDate) continue;
      final pauseEnd = period.endDate ?? target;
      final effectiveStart = _laterDate(start, period.startDate);
      final effectiveEnd = _earlierDate(target, pauseEnd);
      if (effectiveEnd.isAfter(effectiveStart)) {
        pausedDays += effectiveEnd.difference(effectiveStart).inDays;
      }
    }
    return pausedDays;
  }
}

List<ProgramPausePeriod> _mergePausePeriods(List<ProgramPausePeriod> periods) {
  final sorted =
      periods
          .where((p) => p.endDate == null || p.endDate!.isAfter(p.startDate))
          .map(
            (p) => ProgramPausePeriod(
              startDate: _dateOnly(p.startDate),
              endDate: p.endDate == null ? null : _dateOnly(p.endDate!),
              extendEndDate: p.extendEndDate,
            ),
          )
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
  final merged = <ProgramPausePeriod>[];
  for (final period in sorted) {
    if (merged.isEmpty) {
      merged.add(period);
      continue;
    }
    final last = merged.last;
    if (last.endDate == null) {
      if (period.extendEndDate && !last.extendEndDate) {
        merged[merged.length - 1] = last.copyWith(extendEndDate: true);
      }
      continue;
    }
    if (period.startDate.isAfter(last.endDate!)) {
      merged.add(period);
      continue;
    }
    final nextEnd = period.endDate == null
        ? null
        : period.endDate!.isAfter(last.endDate!)
        ? period.endDate
        : last.endDate;
    merged[merged.length - 1] = ProgramPausePeriod(
      startDate: last.startDate,
      endDate: nextEnd,
      extendEndDate: last.extendEndDate || period.extendEndDate,
    );
  }
  return merged;
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

DateTime _earlierDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime _laterDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

bool _pausePeriodListsEqual(
  List<ProgramPausePeriod> a,
  List<ProgramPausePeriod> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
  final int? daysSinceLastLog;
  final int? lastLoggedSets;
  final int? lastLoggedReps;
  final double? lastLoggedWeightKg;

  const WorkoutPrescription({
    required this.programId,
    required this.programDayId,
    required this.programExerciseId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weightKg,
    this.reason = '',
    this.daysSinceLastLog,
    this.lastLoggedSets,
    this.lastLoggedReps,
    this.lastLoggedWeightKg,
  });

  bool get shouldOfferRecoveryLoad =>
      daysSinceLastLog != null &&
      daysSinceLastLog! > 7 &&
      lastLoggedSets != null &&
      lastLoggedReps != null &&
      lastLoggedWeightKg != null;

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
        daysSinceLastLog: json['daysSinceLastLog'] as int?,
        lastLoggedSets: json['lastLoggedSets'] as int?,
        lastLoggedReps: json['lastLoggedReps'] as int?,
        lastLoggedWeightKg: (json['lastLoggedWeightKg'] as num?)?.toDouble(),
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
    'daysSinceLastLog': daysSinceLastLog,
    'lastLoggedSets': lastLoggedSets,
    'lastLoggedReps': lastLoggedReps,
    'lastLoggedWeightKg': lastLoggedWeightKg,
  };

  WorkoutPrescription copyWith({
    String? programId,
    String? programDayId,
    String? programExerciseId,
    String? exerciseId,
    int? sets,
    int? reps,
    double? weightKg,
    String? reason,
    int? daysSinceLastLog,
    int? lastLoggedSets,
    int? lastLoggedReps,
    double? lastLoggedWeightKg,
  }) => WorkoutPrescription(
    programId: programId ?? this.programId,
    programDayId: programDayId ?? this.programDayId,
    programExerciseId: programExerciseId ?? this.programExerciseId,
    exerciseId: exerciseId ?? this.exerciseId,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    reason: reason ?? this.reason,
    daysSinceLastLog: daysSinceLastLog ?? this.daysSinceLastLog,
    lastLoggedSets: lastLoggedSets ?? this.lastLoggedSets,
    lastLoggedReps: lastLoggedReps ?? this.lastLoggedReps,
    lastLoggedWeightKg: lastLoggedWeightKg ?? this.lastLoggedWeightKg,
  );
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
