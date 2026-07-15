import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';

typedef WorkoutLogIdFactory = String Function();

class WorkoutEntryDraft {
  final String exerciseId;
  final int sets;
  final int reps;
  final double weight;
  final String? programId;
  final String? programDayId;
  final String? programExerciseId;

  const WorkoutEntryDraft({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
    this.programId,
    this.programDayId,
    this.programExerciseId,
  });

  bool get hasProgramSlot =>
      programId?.trim().isNotEmpty == true &&
      programDayId?.trim().isNotEmpty == true &&
      programExerciseId?.trim().isNotEmpty == true;

  bool get hasPartialProgramSlot {
    final presentCount = [
      programId,
      programDayId,
      programExerciseId,
    ].where((value) => value != null).length;
    return presentCount > 0 && presentCount < 3;
  }

  bool get hasInvalidProgramSlot =>
      [
        programId,
        programDayId,
        programExerciseId,
      ].any((value) => value != null) &&
      !hasProgramSlot;
}

class WorkoutLogBundle {
  final WorkoutLog workoutLog;
  final List<WorkoutSetLog> setLogs;

  const WorkoutLogBundle({required this.workoutLog, required this.setLogs});
}

class WorkoutSavePlan {
  final List<WorkoutLogBundle> bundles;
  final Set<String> savedCurrentProgramExerciseIds;
  final bool shouldAdvanceProgram;

  const WorkoutSavePlan({
    required this.bundles,
    required this.savedCurrentProgramExerciseIds,
    required this.shouldAdvanceProgram,
  });

  List<WorkoutLog> get workoutLogs => [
    for (final bundle in bundles) bundle.workoutLog,
  ];
}

WorkoutSavePlan buildWorkoutSavePlan({
  required List<WorkoutEntryDraft> drafts,
  required String userId,
  required DateTime workoutDate,
  required DateTime createdAt,
  required WorkoutLogIdFactory idFactory,
  required TrainingProgram? activeProgram,
  required ProgramDay? activeProgramDay,
  required bool selectedDateIsToday,
}) {
  for (final draft in drafts) {
    if (draft.hasInvalidProgramSlot) {
      throw ArgumentError(
        'Program slot identifiers must be all null or all non-blank.',
      );
    }
  }

  final bundles = <WorkoutLogBundle>[];
  final savedCurrentProgramExerciseIds = <String>{};

  for (final draft in drafts) {
    final workoutLog = WorkoutLog(
      id: idFactory(),
      userId: userId,
      exerciseId: draft.exerciseId,
      programId: draft.programId,
      programDayId: draft.programDayId,
      programExerciseId: draft.programExerciseId,
      date: workoutDate,
      sets: draft.sets,
      reps: draft.reps,
      weightKg: draft.weight,
      createdAt: createdAt,
    );
    final setLogs = <WorkoutSetLog>[];

    if (draft.hasProgramSlot) {
      final programId = draft.programId!;
      final programDayId = draft.programDayId!;
      final programExerciseId = draft.programExerciseId!;
      if (activeProgram != null &&
          activeProgramDay != null &&
          programId == activeProgram.id &&
          programDayId == activeProgramDay.id) {
        savedCurrentProgramExerciseIds.add(programExerciseId);
      }
      for (var setIndex = 0; setIndex < draft.sets; setIndex++) {
        setLogs.add(
          WorkoutSetLog(
            id: idFactory(),
            workoutLogId: workoutLog.id,
            programId: programId,
            programDayId: programDayId,
            programExerciseId: programExerciseId,
            setIndex: setIndex,
            reps: draft.reps,
            weightKg: draft.weight,
            completed: true,
          ),
        );
      }
    }

    bundles.add(
      WorkoutLogBundle(
        workoutLog: workoutLog,
        setLogs: List.unmodifiable(setLogs),
      ),
    );
  }

  return WorkoutSavePlan(
    bundles: List.unmodifiable(bundles),
    savedCurrentProgramExerciseIds: Set.unmodifiable(
      savedCurrentProgramExerciseIds,
    ),
    shouldAdvanceProgram: shouldAdvanceProgram(
      currentDay: activeProgramDay,
      savedProgramExerciseIds: savedCurrentProgramExerciseIds,
      advanceMode: activeProgram?.advanceMode ?? AdvanceMode.manual,
      selectedDateIsToday: selectedDateIsToday,
    ),
  );
}
