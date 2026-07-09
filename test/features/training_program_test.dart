import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/repositories/app_database.dart';
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

    test('default percentIncrement remains 2.5', () {
      expect(const ProgressionScheme().percentIncrement, 2.5);
      expect(ProgressionScheme.fromJson({}).percentIncrement, 2.5);
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

    test('legacy periodized type falls back to fixed load', () {
      final scheme = ProgressionScheme.fromJson({'type': 'periodized'});
      expect(scheme.type, ProgressionSchemeType.fixedLoad);
    });

    test('missing numeric fields use defaults', () {
      final scheme = ProgressionScheme.fromJson({'type': 'linearWeight'});
      expect(scheme.weightIncrementKg, 2.5);
      expect(scheme.percentIncrement, 2.5);
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

    test('JSON roundtrip preserves deload day', () {
      final day = ProgramDay(
        id: 'pd_deload',
        name: 'Deload',
        kind: DayKind.deload,
      );
      final restored = ProgramDay.fromJson(day.toJson());
      expect(restored.kind, DayKind.deload);
      expect(restored.toJson()['kind'], 'deload');
      expect(restored.isTrainingLike, isTrue);
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

  group('createDeloadDayFrom', () {
    ProgramDay baseDay() => ProgramDay(
      id: 'pd_base',
      name: 'Push',
      kind: DayKind.training,
      exercises: [
        ProgramExercise(
          id: 'pe_bench',
          exerciseId: 'ex_bench',
          targetSets: 5,
          minReps: 5,
          maxReps: 9,
          startingWeightKg: 82.35,
          progressionScheme: const ProgressionScheme(
            type: ProgressionSchemeType.linearWeight,
            weightIncrementKg: 2.5,
          ),
          sortOrder: 2,
        ),
        ProgramExercise(
          id: 'pe_press',
          exerciseId: 'ex_press',
          targetSets: 1,
          minReps: 1,
          maxReps: 2,
          startingWeightKg: 40,
          sortOrder: 1,
        ),
      ],
    );

    test(
      'standard uses default 70 percent weight, unchanged sets and reps, fixed load, and new ids',
      () {
        final deload = createDeloadDayFrom(
          baseDay: baseDay(),
          id: 'pd_deload',
          name: 'Deload Push',
          exerciseIdBuilder: (index, source) => 'deload_${source.id}_$index',
        );

        expect(deload.id, 'pd_deload');
        expect(deload.name, 'Deload Push');
        expect(deload.kind, DayKind.deload);
        expect(deload.exercises.length, 2);

        final exercise = deload.exercises.first;
        expect(exercise.id, 'deload_pe_bench_0');
        expect(exercise.exerciseId, 'ex_bench');
        expect(exercise.sortOrder, 2);
        expect(exercise.startingWeightKg, 57.6);
        expect(exercise.targetSets, 5);
        expect(exercise.minReps, 5);
        expect(exercise.maxReps, 9);
        expect(
          exercise.progressionScheme.type,
          ProgressionSchemeType.fixedLoad,
        );
        expect(exercise.progressionScheme.weightIncrementKg, 0);
      },
    );

    test(
      'volume keeps sets and weight unchanged and halves reps with floor and clamp',
      () {
        final deload = createDeloadDayFrom(
          baseDay: baseDay(),
          id: 'pd_deload',
          name: 'Volume Deload',
          exerciseIdBuilder: (index, _) => 'deload_$index',
          preset: DeloadDayPreset.volume,
          weightPercent: 10,
          setRatio: 0.1,
        );

        expect(deload.exercises.first.startingWeightKg, 82.35);
        expect(deload.exercises.first.targetSets, 5);
        expect(deload.exercises.first.minReps, 2);
        expect(deload.exercises.first.maxReps, 4);
        expect(deload.exercises.last.targetSets, 1);
        expect(deload.exercises.last.minReps, 1);
        expect(deload.exercises.last.maxReps, 1);
      },
    );

    test(
      'custom applies weight percent, set ratio, and rep ratio independently',
      () {
        final deload = createDeloadDayFrom(
          baseDay: baseDay(),
          id: 'pd_deload',
          name: 'Custom Deload',
          exerciseIdBuilder: (index, _) => 'custom_$index',
          preset: DeloadDayPreset.custom,
          weightPercent: 55,
          setRatio: 0.6,
          repRatio: 0.5,
        );

        final exercise = deload.exercises.first;
        expect(exercise.startingWeightKg, 45.3);
        expect(exercise.targetSets, 3);
        expect(exercise.minReps, 2);
        expect(exercise.maxReps, 4);
        expect(deload.exercises.last.targetSets, 1);
        expect(deload.exercises.last.minReps, 1);
        expect(deload.exercises.last.maxReps, 1);
      },
    );

    test('deload JSON and source metadata roundtrip', () {
      final deload = createDeloadDayFrom(
        baseDay: baseDay(),
        id: 'pd_deload',
        name: 'Custom Deload',
        exerciseIdBuilder: (index, source) => 'custom_${source.id}_$index',
        preset: DeloadDayPreset.custom,
        weightPercent: 60,
        setRatio: 0.75,
        repRatio: 0.5,
      );

      final restored = ProgramDay.fromJson(deload.toJson());

      expect(restored.deloadSourceDayId, 'pd_base');
      expect(restored.deloadPreset, DeloadDayPreset.custom);
      expect(restored.deloadWeightPercent, 60);
      expect(restored.deloadSetRatio, 0.75);
      expect(restored.deloadRepRatio, 0.5);
      expect(restored.exercises.first.id, 'custom_pe_bench_0');
      expect(restored.exercises.first.deloadSourceExerciseId, 'pe_bench');
    });

    test('empty base day creates empty deload day', () {
      final deload = createDeloadDayFrom(
        baseDay: ProgramDay(id: 'pd_empty', name: 'Empty'),
        id: 'pd_deload',
        name: 'Empty Deload',
        exerciseIdBuilder: (index, _) => 'deload_$index',
      );

      expect(deload.kind, DayKind.deload);
      expect(deload.exercises, isEmpty);
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
          activatedAt: now,
          activatedDayIndex: 1,
          plannedCycleCount: 6,
          advanceMode: AdvanceMode.manual,
          pausePeriods: [
            ProgramPausePeriod(
              startDate: DateTime(2025, 6, 3),
              endDate: DateTime(2025, 6, 5),
              extendEndDate: false,
            ),
          ],
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
        expect(restored.activatedAt, now);
        expect(restored.activatedDayIndex, 1);
        expect(restored.plannedCycleCount, 6);
        expect(restored.advanceMode, AdvanceMode.manual);
        expect(restored.pausePeriods.length, 1);
        expect(restored.pausePeriods.first.startDate.year, 2025);
        expect(restored.pausePeriods.first.startDate.month, 6);
        expect(restored.pausePeriods.first.startDate.day, 3);
        expect(restored.pausePeriods.first.endDate?.day, 5);
        expect(restored.pausePeriods.first.extendEndDate, false);

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
      expect(program.activatedAt, isNull);
      expect(program.activatedDayIndex, 0);
      expect(program.plannedCycleCount, isNull);
      expect(program.pausePeriods, isEmpty);
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

    test('copyWith can update activation metadata', () {
      final activatedAt = DateTime(2025, 6, 2, 12);
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        createdAt: now,
        updatedAt: now,
      );
      final updated = program.copyWith(
        active: true,
        activatedAt: activatedAt,
        activatedDayIndex: 2,
        plannedCycleCount: 8,
      );
      expect(updated.active, true);
      expect(updated.activatedAt, activatedAt);
      expect(updated.activatedDayIndex, 2);
      expect(updated.plannedCycleCount, 8);
    });

    test('copyWith can clear planned cycle count for continuous plans', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        plannedCycleCount: 8,
        createdAt: now,
        updatedAt: now,
      );

      final updated = program.copyWith(clearPlannedCycleCount: true);

      expect(updated.plannedCycleCount, isNull);
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

    test('programDayForDate projects from activation day without drift', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        currentDayIndex: 3,
        activatedAt: DateTime(2025, 6, 1, 15),
        activatedDayIndex: 1,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      );

      expect(program.programDayForDate(DateTime(2025, 5, 31)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Pull');
      expect(program.programDayForDate(DateTime(2025, 6, 2))?.name, 'Legs');
      expect(program.programDayForDate(DateTime(2025, 6, 3))?.name, 'Rest');
      expect(program.programDayForDate(DateTime(2025, 6, 4))?.name, 'Push');
    });

    test(
      'programDayForWorkoutDate uses completion state today and projection otherwise',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          active: true,
          currentDayIndex: 3,
          activatedAt: DateTime(2025, 6, 1, 15),
          activatedDayIndex: 1,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
            ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
          ],
        );

        expect(
          program
              .programDayForWorkoutDate(
                DateTime(2025, 6, 1),
                today: DateTime(2025, 6, 1, 20),
              )
              ?.name,
          'Rest',
        );
        expect(
          program
              .programDayForWorkoutDate(
                DateTime(2025, 6, 2),
                today: DateTime(2025, 6, 1, 20),
              )
              ?.name,
          'Legs',
        );
      },
    );

    test('programDayForDate stops after planned cycle count', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        plannedCycleCount: 2,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      );

      expect(program.programDayForDate(DateTime(2025, 5, 31)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Push');
      expect(program.programDayForDate(DateTime(2025, 6, 4))?.name, 'Rest');
      expect(program.programDayForDate(DateTime(2025, 6, 5))?.name, 'Push');
      expect(program.programDayForDate(DateTime(2025, 6, 8))?.name, 'Rest');
      expect(program.programDayForDate(DateTime(2025, 6, 9)), isNull);
      expect(program.plannedEndDate(), DateTime.utc(2025, 6, 8));
    });

    test(
      'programDayForDate repeats continuously with no planned cycle count',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          active: true,
          activatedAt: DateTime(2025, 6, 1),
          activatedDayIndex: 0,
          plannedCycleCount: null,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
            ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
          ],
        );

        expect(program.programDayForDate(DateTime(2025, 5, 31)), isNull);
        expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Push');
        expect(program.programDayForDate(DateTime(2025, 7, 1))?.name, 'Legs');
        expect(program.programDayForDate(DateTime(2026, 1, 2))?.name, 'Rest');
        expect(program.plannedEndDate(), isNull);
      },
    );

    test('extendable pause shifts finite planned end date', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                activatedDayIndex: 0,
                plannedCycleCount: 2,
                createdAt: now,
                updatedAt: now,
                days: [
                  ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
                  ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
                  ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
                  ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
                ],
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now)
              .resumeFrom(DateTime(2025, 6, 6), now: now);

      expect(program.programDayForDate(DateTime(2025, 6, 3)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 5)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 6))?.name, 'Legs');
      expect(program.programDayForDate(DateTime(2025, 6, 11))?.name, 'Rest');
      expect(program.programDayForDate(DateTime(2025, 6, 12)), isNull);
      expect(program.plannedEndDate(), DateTime.utc(2025, 6, 11));
    });

    test('non-extendable pause does not shift finite planned end date', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                activatedDayIndex: 0,
                plannedCycleCount: 2,
                createdAt: now,
                updatedAt: now,
                days: [
                  ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
                  ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
                  ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
                  ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
                ],
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now, extendEndDate: false)
              .resumeFrom(DateTime(2025, 6, 6), now: now);

      expect(program.programDayForDate(DateTime(2025, 6, 3)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 6))?.name, 'Pull');
      expect(program.programDayForDate(DateTime(2025, 6, 8))?.name, 'Rest');
      expect(program.programDayForDate(DateTime(2025, 6, 9)), isNull);
      expect(program.plannedEndDate(), DateTime.utc(2025, 6, 8));
    });

    test('programDayForWorkoutDate returns null after planned interval', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        currentDayIndex: 0,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        plannedCycleCount: 1,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Rest', kind: DayKind.rest),
        ],
      );

      expect(
        program.programDayForWorkoutDate(
          DateTime(2025, 6, 3),
          today: DateTime(2025, 6, 3, 12),
        ),
        isNull,
      );
    });

    test('programDayForDate returns null for inactive or empty programs', () {
      final inactive = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: false,
        activatedAt: now,
        createdAt: now,
        updatedAt: now,
        days: [ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training)],
      );
      final empty = TrainingProgram(
        id: 'prog2',
        userId: 'user1',
        name: 'Empty',
        active: true,
        activatedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(inactive.programDayForDate(now), isNull);
      expect(empty.programDayForDate(now), isNull);
    });

    test('programDayForDate normalizes activated day index', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'Two day',
        active: true,
        activatedAt: now,
        activatedDayIndex: 5,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Train', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Rest', kind: DayKind.rest),
        ],
      );
      expect(program.programDayForDate(now)?.name, 'Rest');
      expect(
        program.programDayForDate(now.add(const Duration(days: 1)))?.name,
        'Train',
      );
    });

    test(
      'programDayForDate uses current day index for migrated active data',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'Migrated',
          active: true,
          currentDayIndex: 2,
          createdAt: DateTime(2025, 5, 1),
          updatedAt: DateTime(2025, 6, 1),
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
            ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
          ],
        );

        expect(program.activatedAt, isNull);
        expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Legs');
        expect(program.programDayForDate(DateTime(2025, 6, 2))?.name, 'Rest');
      },
    );

    test('open pause returns null from pause start onward', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
        ],
      ).pauseFrom(DateTime(2025, 6, 3), now: now);

      expect(program.isPausedOn(DateTime(2025, 6, 2)), false);
      expect(program.isPausedOn(DateTime(2025, 6, 3)), true);
      expect(program.programDayForDate(DateTime(2025, 6, 2))?.name, 'Pull');
      expect(program.programDayForDate(DateTime(2025, 6, 3)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 10)), isNull);
    });

    test('pause from a past date opens pause from selected start', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
        ],
      ).pauseFrom(DateTime(2025, 6, 2, 20), now: DateTime(2025, 6, 5, 9));

      expect(program.updatedAt, DateTime(2025, 6, 5, 9));
      expect(program.pausePeriods.single.startDate, DateTime.utc(2025, 6, 2));
      expect(program.pausePeriods.single.endDate, isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Push');
      expect(program.programDayForDate(DateTime(2025, 6, 2)), isNull);
      expect(program.isPausedNow(today: DateTime(2025, 6, 5)), true);
    });

    test('pause before activation clamps to activation date', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 3),
        activatedDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
        ],
      ).pauseFrom(DateTime(2025, 6, 1), now: now);

      expect(program.pausePeriods.single.startDate, DateTime.utc(2025, 6, 3));
      expect(program.isPausedOn(DateTime(2025, 6, 2)), false);
      expect(program.programDayForDate(DateTime(2025, 6, 2)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 3)), isNull);
    });

    test('closed pause shifts projection after resume date', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                activatedDayIndex: 0,
                createdAt: now,
                updatedAt: now,
                days: [
                  ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
                  ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
                  ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
                  ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
                ],
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now)
              .resumeFrom(DateTime(2025, 6, 6), now: now);

      expect(program.programDayForDate(DateTime(2025, 6, 1))?.name, 'Push');
      expect(program.programDayForDate(DateTime(2025, 6, 2))?.name, 'Pull');
      expect(program.programDayForDate(DateTime(2025, 6, 3)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 5)), isNull);
      expect(program.programDayForDate(DateTime(2025, 6, 6))?.name, 'Legs');
      expect(program.programDayForDate(DateTime(2025, 6, 7))?.name, 'Rest');
    });

    test('programDayForWorkoutDate returns null when today is paused', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        currentDayIndex: 1,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
        ],
      ).pauseFrom(DateTime(2025, 6, 3), now: now);

      expect(
        program.programDayForWorkoutDate(
          DateTime(2025, 6, 3),
          today: DateTime(2025, 6, 3, 12),
        ),
        isNull,
      );
    });

    test('resume from a past date closes the pause before today', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                activatedDayIndex: 0,
                createdAt: now,
                updatedAt: now,
                days: [
                  ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
                  ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
                  ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
                ],
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now)
              .resumeFrom(DateTime(2025, 6, 5), now: now);

      expect(program.isPausedOn(DateTime(2025, 6, 4)), true);
      expect(program.isPausedOn(DateTime(2025, 6, 5)), false);
      expect(program.programDayForDate(DateTime(2025, 6, 5))?.name, 'Legs');
    });

    test('pausing again while paused keeps the earlier start date', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                createdAt: now,
                updatedAt: now,
              )
              .pauseFrom(DateTime(2025, 6, 5), now: now)
              .pauseFrom(DateTime(2025, 6, 3), now: now);

      expect(program.pausePeriods.length, 1);
      expect(program.pausePeriods.first.startDate.day, 3);
      expect(program.pausePeriods.first.endDate, isNull);
    });

    test('pausing while already paused does not duplicate open pause', () {
      final paused = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 1),
        createdAt: now,
        updatedAt: now,
      ).pauseFrom(DateTime(2025, 6, 3), now: DateTime(2025, 6, 3));

      final duplicate = paused.pauseFrom(
        DateTime(2025, 6, 5),
        now: DateTime(2025, 6, 5),
      );

      expect(duplicate.pausePeriods.length, 1);
      expect(duplicate.pausePeriods.first.startDate, DateTime.utc(2025, 6, 3));
      expect(duplicate.pausePeriods.first.endDate, isNull);
      expect(duplicate.updatedAt, DateTime(2025, 6, 3));
    });

    test('resume on pause start cancels zero length pause', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                createdAt: now,
                updatedAt: now,
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now)
              .resumeFrom(DateTime(2025, 6, 3), now: now);

      expect(program.pausePeriods, isEmpty);
    });

    test('overlapping pause periods are merged before projection', () {
      final program =
          TrainingProgram(
                id: 'prog1',
                userId: 'user1',
                name: 'PPL',
                active: true,
                activatedAt: DateTime(2025, 6, 1),
                activatedDayIndex: 0,
                createdAt: now,
                updatedAt: now,
                days: [
                  ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
                  ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
                  ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
                ],
              )
              .pauseFrom(DateTime(2025, 6, 3), now: now)
              .resumeFrom(DateTime(2025, 6, 5), now: now)
              .pauseFrom(DateTime(2025, 6, 4), now: now)
              .resumeFrom(DateTime(2025, 6, 7), now: now);

      expect(program.pausePeriods.length, 1);
      expect(program.pausePeriods.first.startDate.day, 3);
      expect(program.pausePeriods.first.endDate?.day, 7);
      expect(program.programDayForDate(DateTime(2025, 6, 7))?.name, 'Legs');
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

    test(
      'insertDayAt keeps current day stable when inserting before or at current day',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: '3 on 1 off',
          currentDayIndex: 1,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ],
        );
        final deload = ProgramDay(
          id: 'deload',
          name: 'Deload',
          kind: DayKind.deload,
        );

        final insertedBefore = program.insertDayAt(0, deload, insertedAt: now);
        expect(insertedBefore.currentDayIndex, 2);
        expect(insertedBefore.currentDay?.id, 'd2');

        final insertedAt = program.insertDayAt(1, deload, insertedAt: now);
        expect(insertedAt.currentDayIndex, 2);
        expect(insertedAt.currentDay?.id, 'd2');
      },
    );

    test('insertDayAt leaves current day stable when inserting after it', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: '3 on 1 off',
        currentDayIndex: 1,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
        ],
      );

      final updated = program.insertDayAt(
        99,
        ProgramDay(id: 'deload', name: 'Deload', kind: DayKind.deload),
        insertedAt: DateTime(2025, 6, 2),
      );

      expect(updated.currentDayIndex, 1);
      expect(updated.currentDay?.id, 'd2');
      expect(updated.updatedAt, DateTime(2025, 6, 2));
    });

    test(
      'insertDayAt keeps activated day stable when inserting before or at activated day',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          activatedAt: now,
          activatedDayIndex: 2,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
          ],
        );
        final deload = ProgramDay(
          id: 'deload',
          name: 'Deload',
          kind: DayKind.deload,
        );

        final insertedBefore = program.insertDayAt(1, deload, insertedAt: now);
        expect(insertedBefore.activatedDayIndex, 3);
        expect(insertedBefore.days[insertedBefore.activatedDayIndex].id, 'd3');

        final insertedAt = program.insertDayAt(2, deload, insertedAt: now);
        expect(insertedAt.activatedDayIndex, 3);
        expect(insertedAt.days[insertedAt.activatedDayIndex].id, 'd3');
      },
    );

    test('insertDayAt leaves activated day stable when inserting after it', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        activatedAt: now,
        activatedDayIndex: 0,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
        ],
      );

      final updated = program.insertDayAt(
        2,
        ProgramDay(id: 'deload', name: 'Deload', kind: DayKind.deload),
        insertedAt: now,
      );

      expect(updated.activatedDayIndex, 0);
      expect(updated.days[updated.activatedDayIndex].id, 'd1');
    });

    test('endExecution stops projection and clears pauses', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        active: true,
        activatedAt: DateTime(2025, 6, 1),
        activatedDayIndex: 0,
        plannedCycleCount: 3,
        createdAt: now,
        updatedAt: now,
        days: [
          ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
          ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
          ProgramDay(id: 'd3', name: 'Rest', kind: DayKind.rest),
        ],
      ).pauseFrom(DateTime(2025, 6, 5), now: DateTime(2025, 6, 5));

      final ended = program.endExecution(endedAt: DateTime(2025, 6, 6));

      expect(ended.active, false);
      expect(ended.pausePeriods, isEmpty);
      expect(ended.updatedAt, DateTime(2025, 6, 6));
      expect(ended.days.length, 3);
      expect(ended.programDayForDate(DateTime(2025, 6, 1)), isNull);
      expect(
        ended.programDayForWorkoutDate(
          DateTime(2025, 6, 6),
          today: DateTime(2025, 6, 6),
        ),
        isNull,
      );
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

    test('removeDayAt keeps activated day stable when deleting before it', () {
      final program = TrainingProgram(
        id: 'prog1',
        userId: 'user1',
        name: 'PPL',
        currentDayIndex: 2,
        activatedAt: now,
        activatedDayIndex: 2,
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
      expect(updated.activatedDayIndex, 1);
      expect(updated.days[updated.activatedDayIndex].id, 'd3');
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
      'refreshLinkedDeloadsForDay updates weights and preserves deload exercise ids',
      () {
        final sourceDay = ProgramDay(
          id: 'd1',
          name: 'Push',
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: 'pe_bench',
              exerciseId: 'ex_bench',
              targetSets: 3,
              minReps: 8,
              maxReps: 12,
              startingWeightKg: 100,
            ),
          ],
        );
        final deload = createDeloadDayFrom(
          baseDay: sourceDay,
          id: 'd1_deload',
          name: 'Deload Push',
          exerciseIdBuilder: (index, source) => 'deload_${source.id}_$index',
        );
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          createdAt: now,
          updatedAt: now,
          days: [
            sourceDay.copyWith(
              exercises: [
                sourceDay.exercises.first.copyWith(startingWeightKg: 120),
              ],
            ),
            deload,
          ],
        );

        final refreshed = program.refreshLinkedDeloadsForDay(
          'd1',
          refreshedAt: DateTime(2025, 6, 2),
        );

        final refreshedDeload = refreshed.days[1];
        expect(refreshedDeload.exercises.single.id, 'deload_pe_bench_0');
        expect(
          refreshedDeload.exercises.single.deloadSourceExerciseId,
          'pe_bench',
        );
        expect(refreshedDeload.exercises.single.startingWeightKg, 84);
        expect(refreshed.updatedAt, DateTime(2025, 6, 2));
      },
    );

    test(
      'refreshLinkedDeloadsForDay infers and upgrades obvious legacy deloads',
      () {
        final sourceDay = ProgramDay(
          id: 'd1',
          name: 'Push',
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: 'pe_bench',
              exerciseId: 'ex_bench',
              targetSets: 4,
              minReps: 6,
              maxReps: 10,
              startingWeightKg: 120,
            ),
            ProgramExercise(
              id: 'pe_press',
              exerciseId: 'ex_press',
              targetSets: 3,
              minReps: 8,
              maxReps: 12,
              startingWeightKg: 60,
            ),
          ],
        );
        final legacyDeload = ProgramDay(
          id: 'd1_deload',
          name: 'Deload Push',
          kind: DayKind.deload,
          exercises: [
            ProgramExercise(
              id: 'legacy_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 70,
            ),
            ProgramExercise(
              id: 'legacy_press',
              exerciseId: 'ex_press',
              startingWeightKg: 35,
            ),
          ],
        );
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          createdAt: now,
          updatedAt: now,
          days: [
            sourceDay,
            ProgramDay(
              id: 'd2',
              name: 'Pull',
              kind: DayKind.training,
              exercises: [ProgramExercise(id: 'pe_row', exerciseId: 'ex_row')],
            ),
            legacyDeload,
          ],
        );

        final refreshed = program.refreshLinkedDeloadsForDay(
          'd1',
          refreshedAt: DateTime(2025, 6, 2),
        );

        final refreshedDeload = refreshed.days[2];
        expect(refreshedDeload.deloadSourceDayId, 'd1');
        expect(refreshedDeload.exercises[0].id, 'legacy_bench');
        expect(refreshedDeload.exercises[0].deloadSourceExerciseId, 'pe_bench');
        expect(refreshedDeload.exercises[0].startingWeightKg, 84);
        expect(refreshedDeload.exercises[1].id, 'legacy_press');
        expect(refreshedDeload.exercises[1].deloadSourceExerciseId, 'pe_press');
        expect(refreshedDeload.exercises[1].startingWeightKg, 42);
        expect(refreshed.updatedAt, DateTime(2025, 6, 2));
      },
    );

    test(
      'refreshLinkedDeloadsForDay leaves ambiguous legacy deloads unchanged',
      () {
        final sourceDay = ProgramDay(
          id: 'd1',
          name: 'Upper A',
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: 'pe_a_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 120,
            ),
            ProgramExercise(id: 'pe_a_row', exerciseId: 'ex_row'),
          ],
        );
        final duplicateSourceDay = ProgramDay(
          id: 'd2',
          name: 'Upper B',
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: 'pe_b_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 100,
            ),
            ProgramExercise(id: 'pe_b_row', exerciseId: 'ex_row'),
          ],
        );
        final legacyDeload = ProgramDay(
          id: 'upper_deload',
          name: 'Deload',
          kind: DayKind.deload,
          exercises: [
            ProgramExercise(
              id: 'legacy_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 70,
            ),
            ProgramExercise(id: 'legacy_row', exerciseId: 'ex_row'),
          ],
        );
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'Upper',
          createdAt: now,
          updatedAt: now,
          days: [sourceDay, duplicateSourceDay, legacyDeload],
        );

        final refreshed = program.refreshLinkedDeloadsForDay(
          'd1',
          refreshedAt: DateTime(2025, 6, 2),
        );

        expect(identical(refreshed, program), isTrue);
        expect(refreshed.days[2].deloadSourceDayId, isNull);
        expect(refreshed.days[2].exercises[0].deloadSourceExerciseId, isNull);
        expect(refreshed.days[2].exercises[0].startingWeightKg, 70);
        expect(refreshed.updatedAt, now);
      },
    );

    test(
      'refreshLinkedDeloadsForDay leaves single-exercise legacy deloads without name match unchanged',
      () {
        final sourceDay = ProgramDay(
          id: 'd1',
          name: 'Push',
          kind: DayKind.training,
          exercises: [
            ProgramExercise(
              id: 'pe_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 120,
            ),
            ProgramExercise(id: 'pe_press', exerciseId: 'ex_press'),
          ],
        );
        final legacyDeload = ProgramDay(
          id: 'legacy_single',
          name: 'Easy day',
          kind: DayKind.deload,
          exercises: [
            ProgramExercise(
              id: 'legacy_bench',
              exerciseId: 'ex_bench',
              startingWeightKg: 70,
            ),
          ],
        );
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          createdAt: now,
          updatedAt: now,
          days: [sourceDay, legacyDeload],
        );

        final refreshed = program.refreshLinkedDeloadsForDay(
          'd1',
          refreshedAt: DateTime(2025, 6, 2),
        );

        expect(identical(refreshed, program), isTrue);
        expect(refreshed.days[1].deloadSourceDayId, isNull);
        expect(
          refreshed.days[1].exercises.single.deloadSourceExerciseId,
          isNull,
        );
        expect(refreshed.days[1].exercises.single.startingWeightKg, 70);
      },
    );

    test(
      'reorderDay updates order and keeps current and activated day ids stable',
      () {
        final program = TrainingProgram(
          id: 'prog1',
          userId: 'user1',
          name: 'PPL',
          currentDayIndex: 2,
          activatedAt: now,
          activatedDayIndex: 3,
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'd1', name: 'Push', kind: DayKind.training),
            ProgramDay(id: 'd2', name: 'Pull', kind: DayKind.training),
            ProgramDay(id: 'd3', name: 'Legs', kind: DayKind.training),
            ProgramDay(id: 'd4', name: 'Rest', kind: DayKind.rest),
          ],
        );

        final reordered = program.reorderDay(
          3,
          0,
          reorderedAt: DateTime(2025, 6, 2),
        );

        expect(reordered.days.map((day) => day.id), ['d4', 'd1', 'd2', 'd3']);
        expect(reordered.currentDayIndex, 3);
        expect(reordered.currentDay?.id, 'd3');
        expect(reordered.activatedDayIndex, 0);
        expect(reordered.days[reordered.activatedDayIndex].id, 'd4');
        expect(reordered.updatedAt, DateTime(2025, 6, 2));
        expect(identical(program.reorderDay(-1, 0), program), isTrue);
        expect(identical(program.reorderDay(1, 1), program), isTrue);

        final movedDown = program.reorderDay(
          1,
          2,
          reorderedAt: DateTime(2025, 6, 3),
        );

        expect(movedDown.days.map((day) => day.id), ['d1', 'd3', 'd2', 'd4']);
        expect(movedDown.currentDay?.id, 'd3');
        expect(movedDown.days[movedDown.activatedDayIndex].id, 'd4');
        expect(movedDown.updatedAt, DateTime(2025, 6, 3));
      },
    );

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

    test(
      'activeTrainingProgramForUser selects started plan before scheduled start',
      () {
        final current = TrainingProgram(
          id: 'current',
          userId: 'user1',
          name: 'Current',
          active: true,
          activatedAt: DateTime(2025, 6, 1),
          createdAt: now,
          updatedAt: now,
          days: [
            ProgramDay(id: 'current_push', name: 'Current Push'),
            ProgramDay(id: 'current_pull', name: 'Current Pull'),
          ],
        );
        final scheduled = TrainingProgram(
          id: 'scheduled',
          userId: 'user1',
          name: 'Scheduled',
          active: true,
          activatedAt: DateTime(2025, 6, 8),
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
          days: [
            ProgramDay(id: 'scheduled_push', name: 'Scheduled Push'),
            ProgramDay(id: 'scheduled_pull', name: 'Scheduled Pull'),
          ],
        );

        final programs = [current, scheduled];

        expect(
          activeTrainingProgramForUser(
            programs,
            'user1',
            date: DateTime(2025, 6, 7),
          )?.id,
          'current',
        );
        expect(
          activeTrainingProgramForUser(
            programs,
            'user1',
            date: DateTime(2025, 6, 8),
          )?.id,
          'scheduled',
        );
        expect(
          activeTrainingProgramForUser(
            programs,
            'user1',
            date: DateTime(2025, 6, 9),
          )?.programDayForDate(DateTime(2025, 6, 9))?.id,
          'scheduled_pull',
        );
      },
    );

    test(
      'activeTrainingProgramForUser returns null before only future start',
      () {
        final scheduled = TrainingProgram(
          id: 'scheduled',
          userId: 'user1',
          name: 'Scheduled',
          active: true,
          activatedAt: DateTime(2025, 6, 8),
          createdAt: now,
          updatedAt: now,
          days: [ProgramDay(id: 'scheduled_push', name: 'Scheduled Push')],
        );

        expect(
          activeTrainingProgramForUser(
            [scheduled],
            'user1',
            date: DateTime(2025, 6, 7),
          ),
          isNull,
        );
        expect(
          activeTrainingProgramForUser(
            [scheduled],
            'user1',
            date: DateTime(2025, 6, 8),
          )?.id,
          'scheduled',
        );
      },
    );
  });

  group('AppDatabase training program scheduling', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    TrainingProgram program({
      required String id,
      required bool active,
      required DateTime? activatedAt,
      DateTime? updatedAt,
    }) {
      final createdAt = DateTime.now().subtract(const Duration(days: 30));
      return TrainingProgram(
        id: id,
        userId: 'user1',
        name: id,
        active: active,
        activatedAt: activatedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? createdAt,
        days: [ProgramDay(id: '${id}_day', name: id)],
      );
    }

    test(
      'future scheduling preserves current plan and replaces older future',
      () async {
        final database = AppDatabase.instance;
        final today = DateTime.now();
        final currentStart = today.subtract(const Duration(days: 7));
        final oldFutureStart = today.add(const Duration(days: 7));
        final newFutureStart = today.add(const Duration(days: 14));

        await database.saveTrainingPrograms('user1', [
          program(id: 'current', active: true, activatedAt: currentStart),
          program(
            id: 'old_future',
            active: true,
            activatedAt: oldFutureStart,
            updatedAt: today.subtract(const Duration(minutes: 5)),
          ),
          program(id: 'new_future', active: false, activatedAt: null),
        ]);

        await database.setActiveTrainingProgram(
          'user1',
          'new_future',
          activatedAt: newFutureStart,
          plannedCycleCount: 2,
        );

        final byId = {
          for (final item in await database.getTrainingPrograms('user1'))
            item.id: item,
        };
        expect(byId['current']?.active, true);
        expect(byId['old_future']?.active, false);
        expect(byId['new_future']?.active, true);
        expect(byId['new_future']?.activatedAt, newFutureStart);
        expect(byId['new_future']?.plannedCycleCount, 2);
      },
    );

    test(
      'immediate activation deactivates current and future programs',
      () async {
        final database = AppDatabase.instance;
        final today = DateTime.now();
        final currentStart = today.subtract(const Duration(days: 7));
        final futureStart = today.add(const Duration(days: 7));
        final immediateStart = today.subtract(const Duration(days: 1));

        await database.saveTrainingPrograms('user1', [
          program(id: 'current', active: true, activatedAt: currentStart),
          program(id: 'future', active: true, activatedAt: futureStart),
          program(id: 'replacement', active: false, activatedAt: null),
        ]);

        await database.setActiveTrainingProgram(
          'user1',
          'replacement',
          activatedAt: immediateStart,
          plannedCycleCount: null,
        );

        final byId = {
          for (final item in await database.getTrainingPrograms('user1'))
            item.id: item,
        };
        expect(byId['current']?.active, false);
        expect(byId['future']?.active, false);
        expect(byId['replacement']?.active, true);
        expect(byId['replacement']?.activatedAt, immediateStart);
        expect(byId['replacement']?.plannedCycleCount, isNull);
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

    test(
      'cycle load progression adds cycle percent load and drops one rep',
      () {
        final rx = calculate(
          exercise(
            type: ProgressionSchemeType.linearPeriodization,
            minReps: 8,
            maxReps: 12,
          ),
          log(reps: 10, weightKg: 100),
        );
        expect(rx.reps, 9);
        expect(rx.weightKg, 102.5);
      },
    );

    test(
      'cycle load progression starts from start reps without previous log',
      () {
        final rx = calculate(
          exercise(
            type: ProgressionSchemeType.linearPeriodization,
            minReps: 6,
            maxReps: 10,
          ),
          null,
        );
        expect(rx.reps, 10);
        expect(rx.weightKg, 40);
      },
    );

    test('cycle load progression uses configured percent increment', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearPeriodization,
          minReps: 8,
          maxReps: 12,
          percentIncrement: 5.0,
        ),
        log(reps: 12, weightKg: 100),
      );
      expect(rx.reps, 11);
      expect(rx.weightKg, 105);
    });

    test('cycle load progression stops load increases at ending reps', () {
      final rx = calculate(
        exercise(
          type: ProgressionSchemeType.linearPeriodization,
          minReps: 8,
          maxReps: 12,
          percentIncrement: 5.0,
        ),
        log(reps: 8, weightKg: 100),
      );
      expect(rx.reps, 8);
      expect(rx.weightKg, 100);
    });

    test('copyWith can add extended break recovery values', () {
      final rx =
          calculate(
            exercise(type: ProgressionSchemeType.linearPeriodization),
            log(reps: 10, weightKg: 100),
          ).copyWith(
            daysSinceLastLog: 10,
            lastLoggedSets: 3,
            lastLoggedReps: 10,
            lastLoggedWeightKg: 100,
          );
      expect(rx.shouldOfferRecoveryLoad, isTrue);
      expect(rx.daysSinceLastLog, 10);
      expect(rx.lastLoggedReps, 10);
      expect(rx.lastLoggedWeightKg, 100);
    });

    test('no previous log normalizes invalid starting rep range', () {
      final rx = calculate(exercise(minReps: 12, maxReps: 8), null);
      expect(rx.reps, 8);
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
        daysSinceLastLog: 10,
        lastLoggedSets: 3,
        lastLoggedReps: 8,
        lastLoggedWeightKg: 77.5,
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
      expect(restored.daysSinceLastLog, 10);
      expect(restored.lastLoggedSets, 3);
      expect(restored.lastLoggedReps, 8);
      expect(restored.lastLoggedWeightKg, 77.5);
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

    test('advances for deload day when all planned exercise IDs are saved', () {
      final day = ProgramDay(
        id: 'pd_deload',
        name: 'Deload',
        kind: DayKind.deload,
        exercises: [
          ProgramExercise(id: 'deload_pe1', exerciseId: 'ex_bench'),
          ProgramExercise(id: 'deload_pe2', exerciseId: 'ex_shoulder'),
        ],
      );
      expect(
        shouldAdvanceProgram(
          currentDay: day,
          savedProgramExerciseIds: {'deload_pe1', 'deload_pe2'},
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
