import '../../data/models/workout_log.dart';
import '../../data/models/progression_rule.dart';

class ProgressionSuggestion {
  final int sets;
  final int reps;
  final double weightKg;
  final String reason;

  const ProgressionSuggestion({
    required this.sets,
    required this.reps,
    required this.weightKg,
    required this.reason,
  });
}

class ProgressionCalculator {
  const ProgressionCalculator();

  static const int _minSets = 1;
  static const int _maxSets = 999;
  static const int _minRepsBound = 1;
  static const int _maxRepsBound = 9999;

  int _clampSets(int v) => v.clamp(_minSets, _maxSets);
  int _clampReps(int v) => v.clamp(_minRepsBound, _maxRepsBound);
  double _clampWeight(double v) => v < 0 ? 0 : _round1(v);
  double _round1(double v) => (v * 10).round() / 10;

  ProgressionSuggestion calculate({
    required WorkoutLog? lastLog,
    required ProgressionRule rule,
  }) {
    if (lastLog == null) {
      return ProgressionSuggestion(
        sets: _clampSets(rule.defaultSets ?? 3),
        reps: _clampReps(rule.defaultReps ?? 8),
        weightKg: _clampWeight(rule.defaultWeightKg ?? 0),
        reason: 'No previous record. Using default values.',
      );
    }

    final completed =
        lastLog.sets >= rule.targetSets && lastLog.reps >= rule.targetReps;

    if (rule.onlyIfCompleted && !completed) {
      return ProgressionSuggestion(
        sets: _clampSets(lastLog.sets),
        reps: _clampReps(lastLog.reps),
        weightKg: _clampWeight(lastLog.weightKg),
        reason:
            'Target ${rule.targetSets}x${rule.targetReps} not met last time. '
            'Repeat the same weight and reps.',
      );
    }

    switch (rule.type) {
      case ProgressionType.fixedWeight:
        final weight = lastLog.weightKg + rule.increment;
        return ProgressionSuggestion(
          sets: _clampSets(lastLog.sets),
          reps: _clampReps(lastLog.reps),
          weightKg: _clampWeight(weight),
          reason: '+${rule.increment} kg from last time.',
        );

      case ProgressionType.percentWeight:
        final weight = lastLog.weightKg * (1 + rule.increment / 100);
        return ProgressionSuggestion(
          sets: _clampSets(lastLog.sets),
          reps: _clampReps(lastLog.reps),
          weightKg: _clampWeight(weight),
          reason: '+${rule.increment}% weight from last time.',
        );

      case ProgressionType.reps:
        final reps = lastLog.reps + rule.increment.round();
        return ProgressionSuggestion(
          sets: _clampSets(lastLog.sets),
          reps: _clampReps(reps),
          weightKg: _clampWeight(lastLog.weightKg),
          reason: '+${rule.increment.round()} reps from last time.',
        );

      case ProgressionType.doubleProgression:
        final minReps = rule.minReps ?? rule.targetReps;
        final maxReps = rule.maxReps ?? rule.targetReps;
        if (lastLog.reps < maxReps) {
          return ProgressionSuggestion(
            sets: _clampSets(lastLog.sets),
            reps: _clampReps(lastLog.reps + 1),
            weightKg: _clampWeight(lastLog.weightKg),
            reason: 'Add 1 rep until you reach $maxReps reps.',
          );
        }
        return ProgressionSuggestion(
          sets: _clampSets(lastLog.sets),
          reps: _clampReps(minReps),
          weightKg: _clampWeight(lastLog.weightKg + rule.increment),
          reason:
              'Reached $maxReps reps. +${rule.increment} kg and reset to '
              '$minReps reps.',
        );
    }
  }
}
