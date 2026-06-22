import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/core/utils/progression_calculator.dart';

void main() {
  const calc = ProgressionCalculator();

  WorkoutLog log({int sets = 3, int reps = 8, double weight = 100}) =>
      WorkoutLog(
        id: 'l1',
        userId: 'u',
        exerciseId: 'ex_bench_press',
        date: DateTime(2025, 6, 1),
        sets: sets,
        reps: reps,
        weightKg: weight,
      );

  ProgressionRule rule({
    ProgressionType type = ProgressionType.fixedWeight,
    bool enabled = true,
    double increment = 2.5,
    int targetSets = 3,
    int targetReps = 8,
    int? minReps,
    int? maxReps,
    double? defaultWeightKg,
    int? defaultSets,
    int? defaultReps,
    bool onlyIfCompleted = true,
  }) => ProgressionRule(
    id: 'r1',
    userId: 'u',
    exerciseId: 'ex_bench_press',
    type: type,
    enabled: enabled,
    increment: increment,
    targetSets: targetSets,
    targetReps: targetReps,
    minReps: minReps,
    maxReps: maxReps,
    defaultWeightKg: defaultWeightKg,
    defaultSets: defaultSets,
    defaultReps: defaultReps,
    onlyIfCompleted: onlyIfCompleted,
  );

  group('ProgressionCalculator - rule types', () {
    test('fixedWeight adds fixed kg when target met', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 8, weight: 100),
        rule: rule(type: ProgressionType.fixedWeight, increment: 2.5),
      );
      expect(s.weightKg, 102.5);
      expect(s.reps, 8);
      expect(s.sets, 3);
    });

    test('percentWeight adds percentage when target met', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 8, weight: 100),
        rule: rule(type: ProgressionType.percentWeight, increment: 5),
      );
      expect(s.weightKg, 105.0);
    });

    test('reps adds fixed reps when target met', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 8, weight: 100),
        rule: rule(type: ProgressionType.reps, increment: 2),
      );
      expect(s.reps, 10);
      expect(s.weightKg, 100.0);
    });

    test('doubleProgression adds rep below maxReps, weight unchanged', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 10, weight: 100),
        rule: rule(
          type: ProgressionType.doubleProgression,
          increment: 2.5,
          targetSets: 3,
          targetReps: 8,
          minReps: 8,
          maxReps: 12,
        ),
      );
      expect(s.reps, 11);
      expect(s.weightKg, 100.0);
    });
  });

  group('ProgressionCalculator - completion gating', () {
    test('onlyIfCompleted=true keeps values when target not met', () {
      final s = calc.calculate(
        lastLog: log(sets: 2, reps: 6, weight: 100),
        rule: rule(
          type: ProgressionType.fixedWeight,
          increment: 2.5,
          targetSets: 3,
          targetReps: 8,
          onlyIfCompleted: true,
        ),
      );
      expect(s.weightKg, 100.0);
      expect(s.reps, 6);
      expect(s.sets, 2);
    });

    test('onlyIfCompleted=false always progresses', () {
      final s = calc.calculate(
        lastLog: log(sets: 2, reps: 6, weight: 100),
        rule: rule(
          type: ProgressionType.fixedWeight,
          increment: 2.5,
          onlyIfCompleted: false,
        ),
      );
      expect(s.weightKg, 102.5);
    });
  });

  group('ProgressionCalculator - doubleProgression at max', () {
    test('reaching maxReps adds weight and resets to minReps', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 12, weight: 100),
        rule: rule(
          type: ProgressionType.doubleProgression,
          increment: 2.5,
          targetSets: 3,
          targetReps: 12,
          minReps: 8,
          maxReps: 12,
        ),
      );
      expect(s.weightKg, 102.5);
      expect(s.reps, 8);
    });
  });

  group('ProgressionCalculator - defaults and bounds', () {
    test('no last log returns rule defaults', () {
      final s = calc.calculate(
        lastLog: null,
        rule: rule(defaultWeightKg: 40, defaultSets: 4, defaultReps: 6),
      );
      expect(s.weightKg, 40.0);
      expect(s.sets, 4);
      expect(s.reps, 6);
    });

    test('no last log with no defaults uses conservative defaults', () {
      final s = calc.calculate(lastLog: null, rule: rule());
      expect(s.sets, 3);
      expect(s.reps, 8);
      expect(s.weightKg, 0.0);
    });

    test('weight never goes below zero', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 8, weight: 1),
        rule: rule(
          type: ProgressionType.fixedWeight,
          increment: -10,
          onlyIfCompleted: false,
        ),
      );
      expect(s.weightKg, 0.0);
    });

    test('weight rounded to one decimal', () {
      final s = calc.calculate(
        lastLog: log(sets: 3, reps: 8, weight: 100),
        rule: rule(type: ProgressionType.percentWeight, increment: 3.33),
      );
      // 100 * 1.0333 = 103.33 -> 103.3
      expect(s.weightKg, 103.3);
    });
  });

  group('ProgressionRule JSON roundtrip', () {
    test('serializes and deserializes all fields', () {
      final r = rule(
        type: ProgressionType.doubleProgression,
        enabled: false,
        increment: 1.25,
        targetSets: 4,
        targetReps: 10,
        minReps: 8,
        maxReps: 12,
        defaultWeightKg: 60,
        defaultSets: 5,
        defaultReps: 5,
        onlyIfCompleted: false,
      );
      final restored = ProgressionRule.fromJson(r.toJson());
      expect(restored.type, ProgressionType.doubleProgression);
      expect(restored.enabled, false);
      expect(restored.increment, 1.25);
      expect(restored.targetSets, 4);
      expect(restored.targetReps, 10);
      expect(restored.minReps, 8);
      expect(restored.maxReps, 12);
      expect(restored.defaultWeightKg, 60);
      expect(restored.defaultSets, 5);
      expect(restored.defaultReps, 5);
      expect(restored.onlyIfCompleted, false);
    });

    test('copyWith can clear nullable fields', () {
      final r = rule(minReps: 8, maxReps: 12);
      final cleared = r.copyWith(clearMinReps: true);
      expect(cleared.minReps, null);
      expect(cleared.maxReps, 12);
    });
  });
}
