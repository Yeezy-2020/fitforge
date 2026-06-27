import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';

class ProgramPrescriptionCalculator {
  const ProgramPrescriptionCalculator();

  int _clampSets(int v) => v >= 1 ? v : 1;
  int _clampReps(int v) => v >= 1 ? v : 1;
  double _clampWeight(double v) => v < 0 ? 0 : (v * 10).round() / 10;

  ({int min, int max}) _repBounds(ProgramExercise ex) {
    final a = _clampReps(ex.minReps);
    final b = _clampReps(ex.maxReps);
    return a <= b ? (min: a, max: b) : (min: b, max: a);
  }

  int _clampRepsToRange(int reps, ProgramExercise ex) {
    final bounds = _repBounds(ex);
    return reps.clamp(bounds.min, bounds.max).toInt();
  }

  WorkoutPrescription calculate({
    required ProgramExercise programExercise,
    required String programId,
    required String programDayId,
    required WorkoutLog? lastLog,
  }) {
    if (lastLog == null) {
      final bounds = _repBounds(programExercise);
      return WorkoutPrescription(
        programId: programId,
        programDayId: programDayId,
        programExerciseId: programExercise.id,
        exerciseId: programExercise.exerciseId,
        sets: _clampSets(programExercise.targetSets),
        reps: bounds.min,
        weightKg: _clampWeight(programExercise.startingWeightKg),
        reason: 'Start from program',
      );
    }

    final scheme = programExercise.progressionScheme;

    switch (scheme.type) {
      case ProgressionSchemeType.doubleProgression:
        return _doubleProgression(
          programExercise,
          lastLog,
          scheme,
          programId,
          programDayId,
        );
      case ProgressionSchemeType.linearWeight:
        return _linearWeight(
          programExercise,
          lastLog,
          scheme,
          programId,
          programDayId,
        );
      case ProgressionSchemeType.periodized:
        return _periodized(programExercise, lastLog, programId, programDayId);
    }
  }

  WorkoutPrescription _doubleProgression(
    ProgramExercise ex,
    WorkoutLog lastLog,
    ProgressionScheme scheme,
    String programId,
    String programDayId,
  ) {
    final bounds = _repBounds(ex);
    final maxReps = bounds.max;
    if (lastLog.reps < maxReps) {
      return WorkoutPrescription(
        programId: programId,
        programDayId: programDayId,
        programExerciseId: ex.id,
        exerciseId: ex.exerciseId,
        sets: _clampSets(lastLog.sets),
        reps: _clampRepsToRange(lastLog.reps + 1, ex),
        weightKg: _clampWeight(lastLog.weightKg),
        reason: 'Add 1 rep until you reach $maxReps reps',
      );
    }
    return WorkoutPrescription(
      programId: programId,
      programDayId: programDayId,
      programExerciseId: ex.id,
      exerciseId: ex.exerciseId,
      sets: _clampSets(lastLog.sets),
      reps: bounds.min,
      weightKg: _clampWeight(lastLog.weightKg + scheme.weightIncrementKg),
      reason:
          'Reached $maxReps reps. +${scheme.weightIncrementKg} kg and reset to ${bounds.min} reps',
    );
  }

  WorkoutPrescription _linearWeight(
    ProgramExercise ex,
    WorkoutLog lastLog,
    ProgressionScheme scheme,
    String programId,
    String programDayId,
  ) {
    return WorkoutPrescription(
      programId: programId,
      programDayId: programDayId,
      programExerciseId: ex.id,
      exerciseId: ex.exerciseId,
      sets: _clampSets(lastLog.sets),
      reps: _clampRepsToRange(lastLog.reps, ex),
      weightKg: _clampWeight(lastLog.weightKg + scheme.weightIncrementKg),
      reason: '+${scheme.weightIncrementKg} kg from last time',
    );
  }

  WorkoutPrescription _periodized(
    ProgramExercise ex,
    WorkoutLog lastLog,
    String programId,
    String programDayId,
  ) {
    return WorkoutPrescription(
      programId: programId,
      programDayId: programDayId,
      programExerciseId: ex.id,
      exerciseId: ex.exerciseId,
      sets: _clampSets(lastLog.sets),
      reps: _clampReps(lastLog.reps),
      weightKg: _clampWeight(lastLog.weightKg),
      reason: 'Keep last session values',
    );
  }
}
