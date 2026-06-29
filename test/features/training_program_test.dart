import 'package:flutter_test/flutter_test.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/core/utils/program_prescription_calculator.dart';

void main() {
  group('ProgressionScheme', () {
    test('JSON roundtrip preserves all fields', () {
      final scheme = ProgressionScheme(
        type: ProgressionSchemeType.linearWeight,
        weightIncrementKg: 5.0,
        percentIncrement: 10.0,
        periodWeeks: 6,
        deloadPercent: 0.4,
      );
      final restored = ProgressionScheme.fromJson(scheme.toJson());
      expect(restored.type, ProgressionSchemeType.linearWeight);
      expect(restored.weightIncrementKg, 5.0);
      expect(restored.percentIncrement, 10.0);
      expect(restored.periodWeeks, 6);
      expect(restored.deloadPercent, 0.4);
    });

    test('missing type string falls back to doubleProgression', () {
      final json = <String, dynamic>{};
      final scheme = ProgressionScheme.fromJson(json);
      expect(scheme.type, ProgressionSchemeType.doubleProgression);
    });

    test('unknown type string falls back to doubleProgression', () {
      final scheme = ProgressionScheme.fromJson({'type': 'unknownScheme'});
      expect(scheme.type, ProgressionSchemeType.doubleProgression);
    });

    test('new progression type strings roundtrip', () {
      expect(
        ProgressionScheme.fromJson({'type': 'fixedLoad'}).type,
        ProgressionSchemeType.fixedLoad,
      );
      expect(
        ProgressionScheme.fromJson({'type': 'linearPeriodization'}).type,
        ProgressionSchemeType.linearPeriodization,
      );
    });

    test('missing numeric fields use defaults', () {
      final scheme = ProgressionScheme.fromJson({'type': 'linearWeight'});
      expect(scheme.weightIncrementKg, 2.5);
      expect(scheme.percentIncrement, 5.0);
      expect(scheme.periodWeeks, 4);
      expect(scheme.deloadPercent, 0.5);
    });

    test('copyWith updates selected fields', () {
      final scheme = const ProgressionScheme();
      final updated = scheme.copyWith(weightIncrementKg: 10.0, periodWeeks: 8);
      expect(updated.weightIncrementKg, 10.0);
      expect(updated.periodWeeks, 8);
      expect(updated.type, ProgressionSchemeType.doubleProgression);
    });
  });

  group('ProgramExercise', () {
    test('JSON roundtrip preserves all fields', () {
      final exercise = ProgramExercise(
        id: 'pe1',
        exerciseId: 'ex_bench',
        targetSets: 4,
        minReps: 6,
        maxReps: 10,
        startingWeightKg: 60,
        progressionScheme: const ProgressionScheme(
          type: ProgressionSchemeType.linearWeight,
          weightIncrementKg: 2.5,
        ),
        sortOrder: 1,
      );
      final restored = ProgramExercise.fromJson(exercise.toJson());
      expect(restored.id, 'pe1');
      expect(restored.exerciseId, 'ex_bench');
      expect(restored.targetSets, 4);
      expect(restored.minReps, 6);
      expect(restored.maxReps, 10);
      expect(restored.startingWeightKg, 60);
      expect(
        restored.progressionScheme.type,
        ProgressionSchemeType.linearWeight,
      );
      expect(restored.sortOrder, 1);
    });

    test('missing fields use safe defaults', () {
      final exercise = ProgramExercise.fromJson({
        'id': 'pe1',
        'exerciseId': 'ex_squat',
      });
      expect(exercise.targetSets, 3);
      expect(exercise.minReps, 8);
      expect(exercise.maxReps, 12);
      expect(exercise.startingWeightKg, 0);
      expect(exercise.sortOrder, 0);
      expect(
        exercise.progressionScheme.type,
        ProgressionSchemeType.doubleProgression,
      );
    });
  });

  group('ProgramDay', () {
    test('JSON roundtrip preserves training day with exercises', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push Day',
        kind: DayKind.training,
        exercises: [
          ProgramExercise(
            id: 'pe1',
            exerciseId: 'ex_bench',
            targetSets: 3,
            minReps: 8,
            maxReps: 12,
          ),
        ],
      );
      final restored = ProgramDay.fromJson(day.toJson());
      expect(restored.id, 'pd1');
      expect(restored.name, 'Push Day');
      expect(restored.kind, DayKind.training);
      expect(restored.exercises.length, 1);
      expect(restored.exercises[0].id, 'pe1');
    });

    test('JSON roundtrip preserves rest day', () {
      final day = ProgramDay(id: 'pd_rest', name: 'Rest', kind: DayKind.rest);
      final restored = ProgramDay.fromJson(day.toJson());
      expect(restored.kind, DayKind.rest);
      expect(restored.exercises, isEmpty);
    });

    test('missing kind falls back to training', () {
      final day = ProgramDay.fromJson({'id': 'pd1', 'name': 'Unknown'});
      expect(day.kind, DayKind.training);
    });

    test('unknown kind falls back to training', () {
      final day = ProgramDay.fromJson({
        'id': 'pd1',
        'name': 'X',
        'kind': 'fun',
      });
      expect(day.kind, DayKind.training);
    });
  });

  group('TrainingProgram', () {
    final now = DateTime(2025, 6, 1);

    test(
      'JSON roundtrip with training day, rest day, exercise, and scheme',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          active: true,
          currentDayIndex: 2,
          advanceMode: AdvanceMode.manual,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(
              id: 'pd1',
              name: 'Push',
              kind: DayKind.training,
              exercises: [
                ProgramExercise(
                  id: 'pe1',
                  exerciseId: 'ex_bench',
                  targetSets: 3,
                  minReps: 8,
                  maxReps: 12,
                  startingWeightKg: 60,
                  progressionScheme: const ProgressionScheme(
                    type: ProgressionSchemeType.doubleProgression,
                    weightIncrementKg: 2.5,
                  ),
                  sortOrder: 0,
                ),
              ],
            ),
            ProgramDay(id: 'pd2', name: 'Rest', kind: DayKind.rest),
          ],
        );

        final restored = TrainingProgram.fromJson(program.toJson());
        expect(restored.id, 'prog1');
        expect(restored.userId, 'user1');
        expect(restored.name, 'PPL');
        expect(restored.active, true);
        expect(restored.currentDayIndex, 2);
        expect(restored.advanceMode, AdvanceMode.manual);

        expect(restored.days.length, 2);
        expect(restored.days[0].kind, DayKind.training);
        expect(restored.days[1].kind, DayKind.rest);

        final exercise = restored.days[0].exercises[0];
        expect(exercise.id, 'pe1');
        expect(exercise.exerciseId, 'ex_bench');
        expect(
          exercise.progressionScheme.type,
          ProgressionSchemeType.doubleProgression,
        );
        expect(exercise.progressionScheme.weightIncrementKg, 2.5);

        expect(restored.createdAt, now);
        expect(restored.updatedAt, now);
      },
    );

    test('missing enum strings use safe defaults', () {
      final program = TrainingProgram.fromJson({
        'id': 'prog1',
        'userId': 'user1',
        'name': 'Test',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(program.advanceMode, AdvanceMode.auto);
      expect(program.active, false);
      expect(program.currentDayIndex, 0);
      expect(program.days, isEmpty);
    });

    test('unknown advanceMode falls back to auto', () {
      final program = TrainingProgram.fromJson({
        'id': 'prog1',
        'userId': 'user1',
        'name': 'Test',
        'advanceMode': 'unknownMode',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      expect(program.advanceMode, AdvanceMode.auto);
    });

    test('copyWith can update currentDayIndex and active', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        createdAt: now,
        updatedAt: now,
      );
      final updated = program.copyWith(currentDayIndex: 1, active: true);
      expect(updated.currentDayIndex, 1);
      expect(updated.active, true);
      expect(updated.id, 'prog1');
    });

    test('supports "train 3, rest 1" cycle', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      );

      expect(program.days.length, 4);
      expect(program.days.where((d) => d.kind == DayKind.training).length, 3);
      expect(program.days.where((d) => d.kind == DayKind.rest).length, 1);

      // Roundtrip preserves rest days
      final restored = TrainingProgram.fromJson(program.toJson());
      expect(restored.days.length, 4);
      expect(restored.days.where((d) => d.kind == DayKind.rest).length, 1);

      // Simulate advancing through the cycle
      final advanced1 = restored.copyWith(currentDayIndex: 0);
      expect(advanced1.days[advanced1.currentDayIndex].name, 'Push');
      expect(advanced1.days[advanced1.currentDayIndex].kind, DayKind.training);

      final advanced2 = restored.copyWith(currentDayIndex: 3);
      expect(advanced2.days[advanced2.currentDayIndex].name, 'Rest');
      expect(advanced2.days[advanced2.currentDayIndex].kind, DayKind.rest);
    });

    test('advanceToNextDay wraps through training and rest days', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: '3 on 1 off',
        currentDayIndex: 2,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      );

      final restDay = program.advanceToNextDay(advancedAt: now);
      expect(restDay.currentDayIndex, 3);
      expect(restDay.currentDay?.kind, DayKind.rest);

      final wrapped = restDay.advanceToNextDay(advancedAt: now);
      expect(wrapped.currentDayIndex, 0);
      expect(wrapped.currentDay?.name, 'Push');
    });

    test('advanceToNextDay is safe for empty programs', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'Empty',
        currentDayIndex: 0,
        createdAt: now,
        updatedAt: now,
      );

      final advanced = program.advanceToNextDay(advancedAt: now);
      expect(advanced.currentDayIndex, 0);
      expect(advanced.currentDay, isNull);
    });

    test('removeDayAt keeps current day stable when deleting before it', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: '3 on 1 off',
        currentDayIndex: 2,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      );

      final updated = program.removeDayAt(0, removedAt: now);
      expect(updated.currentDayIndex, 1);
      expect(updated.currentDay?.id, 'd3');
    });

    test(
      'removeDayAt moves to the next available day when deleting current',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: '3 on 1 off',
          currentDayIndex: 2,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
            ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
          ],
        );

        final updated = program.removeDayAt(2, removedAt: now);
        expect(updated.currentDayIndex, 2);
        expect(updated.currentDay?.id, 'd4');
      },
    );

    test('removeDayAt handles deleting the only day', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'Single',
        currentDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training)],
      );

      final updated = program.removeDayAt(0, removedAt: now);
      expect(updated.days, isEmpty);
      expect(updated.currentDayIndex, 0);
      expect(updated.currentDay, isNull);
    });

    test(
      'activeTrainingProgramForUser filters stale active programs by user',
      () {
        final user1Program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'User 1',
          active: true,
          createdAt: now,
          updatedAt: now,
        );
        final user2Program = TrainingProgram(
          id: 'prog2',
          userId: 'user2',
          name: 'User 2',
          active: false,
          createdAt: now,
          updatedAt: now,
        );

        expect(
          activeTrainingProgramForUser([user1Program, user2Program], 'user2'),
          isNull,
        );
        expect(
          activeTrainingProgramForUser([
            user1Program,
            user2Program,
          ], 'user1')?.id,
          'prog1',
        );
      },
    );
  });

  group('WorkoutSetLog', () {
    test('JSON roundtrip preserves all fields', () {
      final log = WorkoutSetLog(
        id: 'sl1',
        workoutLogId: 'wl1',
        programId: 'prog1',
        programExerciseId: 'pe1',
        setIndex: 0,
        reps: 10,
        weightKg: 80,
        completed: true,
      );
      final restored = WorkoutSetLog.fromJson(log.toJson());
      expect(restored.id, 'sl1');
      expect(restored.workoutLogId, 'wl1');
      expect(restored.programId, 'prog1');
      expect(restored.programExerciseId, 'pe1');
      expect(restored.setIndex, 0);
      expect(restored.reps, 10);
      expect(restored.weightKg, 80);
      expect(restored.completed, true);
    });

    test('completed defaults to false', () {
      final log = WorkoutSetLog.fromJson({
        'id': 'sl1',
        'workoutLogId': 'wl1',
        'programId': 'prog1',
        'programExerciseId': 'pe1',
        'setIndex': 0,
        'reps': 10,
        'weightKg': 80,
      });
      expect(log.completed, false);
    });

    test('copyWith updates completed status', () {
      final log = WorkoutSetLog(
        id: 'sl1',
        workoutLogId: 'wl1',
        programId: 'prog1',
        programExerciseId: 'pe1',
        setIndex: 0,
        reps: 10,
        weightKg: 80,
      );
      final updated = log.copyWith(completed: true, reps: 12);
      expect(updated.completed, true);
      expect(updated.reps, 12);
      expect(updated.id, 'sl1');
    });
  });

  group('ProgramPrescriptionCalculator', () {
    const calc = ProgramPrescriptionCalculator();

    ProgramExercise exercise({
      ProgressionSchemeType type = ProgressionSchemeType.doubleProgression,
      int targetSets = 3,
      int minReps = 8,
      int maxReps = 12,
      double startingWeightKg = 40,
      double increment = 2.5,
      double percentIncrement = 2.5,
    }) => ProgramExercise(
      id: 'pe1',
      exerciseId: 'ex_bench_press',
      targetSets: targetSets,
      minReps: minReps,
      maxReps: maxReps,
      startingWeightKg: startingWeightKg,
      progressionScheme: ProgressionScheme(
        type: type,
        weightIncrementKg: increment,
        percentIncrement: percentIncrement,
      ),
    );

    WorkoutLog log({int sets = 3, int reps = 8, double weightKg = 60}) =>
        WorkoutLog(
          id: 'log1',
          userId: 'user1',
          exerciseId: 'ex_bench_press',
          date: DateTime(2025, 6, 1),
          sets: sets,
          reps: reps,
          weightKg: weightKg,
        );

    WorkoutPrescription calculate(ProgramExercise exercise, WorkoutLog? log) {
      return calc.calculate(
        programExercise: exercise,
        programId: 'program1',
        programDayId: 'day1',
        lastLog: log,
      );
    }

    test('no previous log uses program starting values', () {
      final rx = calculate(exercise(startingWeightKg: 42.5), null);
      expect(rx.sets, 3);
      expect(rx.reps, 8);
      expect(rx.weightKg, 42.5);
      expect(rx.reason, 'Start from program');
    });

    test('double progression adds one rep below max', () {
      final rx = calculate(exercise(maxReps: 12), log(reps: 10));
      expect(rx.sets, 3);
      expect(rx.reps, 11);
      expect(rx.weightKg, 60);
    });

    test('double progression adds weight and resets reps at max', () {
      final rx = calculate(
        exercise(minReps: 8, maxReps: 12, increment: 2.5),
        log(reps: 12, weightKg: 60),
      );
      expect(rx.reps, 8);
      expect(rx.weightKg, 62.5);
    });

    test('linear progression adds weight and clamps reps into range', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearWeight,
          minReps: 6,
          maxReps: 10,
          increment: 5,
        ),
        log(reps: 12, weightKg: 80),
      );
      expect(rx.reps, 10);
      expect(rx.weightKg, 85);
    });

    test('linear progression normalizes invalid rep ranges', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearWeight,
          minReps: 12,
          maxReps: 8,
          increment: 5,
        ),
        log(reps: 6, weightKg: 80),
      );
      expect(rx.reps, 8);
      expect(rx.weightKg, 85);
    });

    test('fixed load keeps previous load and clamps reps into range', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.fixedLoad,
          minReps: 8,
          maxReps: 12,
        ),
        log(reps: 14, weightKg: 80),
      );
      expect(rx.reps, 12);
      expect(rx.weightKg, 80);
    });

    test('linear periodization adds 2.5 percent load and drops one rep', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearPeriodization,
          minReps: 8,
          maxReps: 12,
          percentIncrement: 5.0,
        ),
        log(reps: 10, weightKg: 100),
      );
      expect(rx.reps, 9);
      expect(rx.weightKg, 102.5);
    });

    test('linear periodization does not drop below minimum reps', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearPeriodization,
          minReps: 8,
          maxReps: 12,
          percentIncrement: 2.5,
        ),
        log(reps: 8, weightKg: 100),
      );
      expect(rx.reps, 8);
      expect(rx.weightKg, 102.5);
    });

    test('no previous log normalizes invalid starting rep range', () {
      final rx = calculate(exercise(minReps: 12, maxReps: 8), null);
      expect(rx.reps, 8);
    });

    test('periodized MVP keeps last session values', () {
      final rx = calculate(
        exercise(type: ProgressionSchemeType.periodized),
        log(sets: 4, reps: 9, weightKg: 75),
      );
      expect(rx.sets, 4);
      expect(rx.reps, 9);
      expect(rx.weightKg, 75);
    });
  });

  group('WorkoutPrescription', () {
    test('JSON roundtrip preserves all fields', () {
      final rx = WorkoutPrescription(
        programId: 'prog1',
        programDayId: 'pd1',
        programExerciseId: 'pe1',
        exerciseId: 'ex_bench',
        sets: 3,
        reps: 8,
        weightKg: 80,
        reason: 'Start of cycle',
      );
      final restored = WorkoutPrescription.fromJson(rx.toJson());
      expect(restored.programId, 'prog1');
      expect(restored.programDayId, 'pd1');
      expect(restored.programExerciseId, 'pe1');
      expect(restored.exerciseId, 'ex_bench');
      expect(restored.sets, 3);
      expect(restored.reps, 8);
      expect(restored.weightKg, 80);
      expect(restored.reason, 'Start of cycle');
    });
  });

  group('shouldAdvanceProgram', () {
    test('advances when all planned exercise IDs are saved', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push',
        kind: DayKind.training,
        exercises: [
          ProgramExercise(id: 'pe1', exerciseId: 'ex_bench'),
          ProgramExercise(id: 'pe2', exerciseId: 'ex_shoulder'),
        ],
      );
      expect(
        shouldAdvanceProgram(
          currentDay: day,
          savedProgramExerciseIds: {'pe1', 'pe2'},
        ),
        isTrue,
      );
    });

    test('does not advance with only manual entries (empty ids)', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push',
        kind: DayKind.training,
        exercises: [ProgramExercise(id: 'pe1', exerciseId: 'ex_bench')],
      );
      expect(
        shouldAdvanceProgram(
          currentDay: day,
          savedProgramExerciseIds: <String>{},
        ),
        isFalse,
      );
    });

    test('does not advance with partial planned entries', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push',
        kind: DayKind.training,
        exercises: [
          ProgramExercise(id: 'pe1', exerciseId: 'ex_bench'),
          ProgramExercise(id: 'pe2', exerciseId: 'ex_shoulder'),
        ],
      );
      expect(
        shouldAdvanceProgram(currentDay: day, savedProgramExerciseIds: {'pe1'}),
        isFalse,
      );
    });

    test('does not advance when program is in manual mode', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push',
        kind: DayKind.training,
        exercises: [ProgramExercise(id: 'pe1', exerciseId: 'ex_bench')],
      );
      expect(
        shouldAdvanceProgram(
          currentDay: day,
          savedProgramExerciseIds: {'pe1'},
          advanceMode: AdvanceMode.manual,
        ),
        isFalse,
      );
    });

    test('does not advance for backfilled dates', () {
      final day = ProgramDay(
        id: 'pd1',
        name: 'Push',
        kind: DayKind.training,
        exercises: [ProgramExercise(id: 'pe1', exerciseId: 'ex_bench')],
      );
      expect(
        shouldAdvanceProgram(
          currentDay: day,
          savedProgramExerciseIds: {'pe1'},
          selectedDateIsToday: false,
        ),
        isFalse,
      );
    });

    test('does not advance on rest day', () {
      final day = ProgramDay(id: 'pd_rest', name: 'Rest', kind: DayKind.rest);
      expect(
        shouldAdvanceProgram(currentDay: day, savedProgramExerciseIds: {'pe1'}),
        isFalse,
      );
    });

    test('does not advance with no active day (null)', () {
      expect(
        shouldAdvanceProgram(
          currentDay: null,
          savedProgramExerciseIds: {'pe1'},
        ),
        isFalse,
      );
    });

    test('does not advance when current day has no exercises', () {
      final day = ProgramDay(id: 'pd1', name: 'Empty', kind: DayKind.training);
      expect(
        shouldAdvanceProgram(currentDay: day, savedProgramExerciseIds: {'pe1'}),
        isFalse,
      );
    });
  });
}
