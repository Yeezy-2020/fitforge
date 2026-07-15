import 'package:fitforge/core/services/workout_log_builder.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final workoutDate = DateTime(2025, 6, 20);
  final createdAt = DateTime(2025, 6, 20, 8, 30);

  TrainingProgram activeProgram({
    List<ProgramExercise> exercises = const [
      ProgramExercise(id: 'program_bench', exerciseId: 'bench'),
    ],
    AdvanceMode advanceMode = AdvanceMode.auto,
  }) {
    return TrainingProgram(
      id: 'program',
      userId: 'user',
      name: 'Program',
      days: [ProgramDay(id: 'day', name: 'Day', exercises: exercises)],
      active: true,
      advanceMode: advanceMode,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  WorkoutLogIdFactory sequentialIds() {
    var next = 0;
    return () => 'id_${next++}';
  }

  test('custom draft builds a slot-free workout log without set logs', () {
    final plan = buildWorkoutSavePlan(
      drafts: const [
        WorkoutEntryDraft(exerciseId: 'custom', sets: 4, reps: 10, weight: 25),
      ],
      userId: 'user',
      workoutDate: workoutDate,
      createdAt: createdAt,
      idFactory: sequentialIds(),
      activeProgram: null,
      activeProgramDay: null,
      selectedDateIsToday: true,
    );

    expect(plan.bundles, hasLength(1));
    expect(plan.workoutLogs.single.id, 'id_0');
    expect(plan.workoutLogs.single.hasProgramSlot, isFalse);
    expect(plan.workoutLogs.single.createdAt, createdAt);
    expect(plan.bundles.single.setLogs, isEmpty);
    expect(plan.savedCurrentProgramExerciseIds, isEmpty);
    expect(plan.shouldAdvanceProgram, isFalse);
  });

  test(
    'complete program slot builds all set logs and advances current day',
    () {
      final program = activeProgram();
      final plan = buildWorkoutSavePlan(
        drafts: const [
          WorkoutEntryDraft(
            exerciseId: 'bench',
            sets: 3,
            reps: 8,
            weight: 80,
            programId: 'program',
            programDayId: 'day',
            programExerciseId: 'program_bench',
          ),
        ],
        userId: 'user',
        workoutDate: workoutDate,
        createdAt: createdAt,
        idFactory: sequentialIds(),
        activeProgram: program,
        activeProgramDay: program.currentDay,
        selectedDateIsToday: true,
      );

      final workoutLog = plan.workoutLogs.single;
      expect(workoutLog.id, 'id_0');
      expect(workoutLog.programId, 'program');
      expect(workoutLog.programDayId, 'day');
      expect(workoutLog.programExerciseId, 'program_bench');
      expect(plan.bundles.single.setLogs, hasLength(3));
      expect(plan.bundles.single.setLogs.map((entry) => entry.id), [
        'id_1',
        'id_2',
        'id_3',
      ]);
      expect(plan.bundles.single.setLogs.map((entry) => entry.setIndex), [
        0,
        1,
        2,
      ]);
      expect(
        plan.bundles.single.setLogs.every(
          (entry) =>
              entry.workoutLogId == 'id_0' &&
              entry.programId == 'program' &&
              entry.programDayId == 'day' &&
              entry.programExerciseId == 'program_bench' &&
              entry.completed,
        ),
        isTrue,
      );
      expect(plan.savedCurrentProgramExerciseIds, {'program_bench'});
      expect(plan.shouldAdvanceProgram, isTrue);
    },
  );

  test('multiple program drafts cover the current day as one save plan', () {
    final program = activeProgram(
      exercises: const [
        ProgramExercise(id: 'program_bench', exerciseId: 'bench'),
        ProgramExercise(id: 'program_row', exerciseId: 'row'),
      ],
    );
    final plan = buildWorkoutSavePlan(
      drafts: const [
        WorkoutEntryDraft(
          exerciseId: 'bench',
          sets: 1,
          reps: 8,
          weight: 80,
          programId: 'program',
          programDayId: 'day',
          programExerciseId: 'program_bench',
        ),
        WorkoutEntryDraft(
          exerciseId: 'row',
          sets: 2,
          reps: 10,
          weight: 60,
          programId: 'program',
          programDayId: 'day',
          programExerciseId: 'program_row',
        ),
      ],
      userId: 'user',
      workoutDate: workoutDate,
      createdAt: createdAt,
      idFactory: sequentialIds(),
      activeProgram: program,
      activeProgramDay: program.currentDay,
      selectedDateIsToday: true,
    );

    expect(plan.workoutLogs, hasLength(2));
    expect(plan.bundles.map((bundle) => bundle.setLogs.length), [1, 2]);
    expect(plan.savedCurrentProgramExerciseIds, {
      'program_bench',
      'program_row',
    });
    expect(plan.shouldAdvanceProgram, isTrue);
  });

  test('partial program slot is rejected before generating any ids', () {
    var generatedIds = 0;
    String idFactory() {
      generatedIds += 1;
      return 'id_$generatedIds';
    }

    expect(
      () => buildWorkoutSavePlan(
        drafts: const [
          WorkoutEntryDraft(exerciseId: 'custom', sets: 1, reps: 5, weight: 10),
          WorkoutEntryDraft(
            exerciseId: 'bench',
            sets: 3,
            reps: 8,
            weight: 80,
            programId: 'program',
            programExerciseId: 'program_bench',
          ),
        ],
        userId: 'user',
        workoutDate: workoutDate,
        createdAt: createdAt,
        idFactory: idFactory,
        activeProgram: null,
        activeProgramDay: null,
        selectedDateIsToday: true,
      ),
      throwsArgumentError,
    );
    expect(generatedIds, 0);
  });

  test('blank program slot fields are rejected before generating ids', () {
    var generatedIds = 0;
    String idFactory() {
      generatedIds += 1;
      return 'id_$generatedIds';
    }

    for (final blank in ['', ' \t\n']) {
      for (var blankIndex = 0; blankIndex < 3; blankIndex += 1) {
        final slot = ['program', 'day', 'program_bench'];
        slot[blankIndex] = blank;

        expect(
          () => buildWorkoutSavePlan(
            drafts: [
              const WorkoutEntryDraft(
                exerciseId: 'custom',
                sets: 1,
                reps: 5,
                weight: 10,
              ),
              WorkoutEntryDraft(
                exerciseId: 'bench',
                sets: 3,
                reps: 8,
                weight: 80,
                programId: slot[0],
                programDayId: slot[1],
                programExerciseId: slot[2],
              ),
            ],
            userId: 'user',
            workoutDate: workoutDate,
            createdAt: createdAt,
            idFactory: idFactory,
            activeProgram: null,
            activeProgramDay: null,
            selectedDateIsToday: true,
          ),
          throwsArgumentError,
          reason: 'slot field $blankIndex must reject ${blank.length} chars',
        );
      }
    }
    expect(generatedIds, 0);
  });

  test('complete slot for another program does not advance active program', () {
    final program = activeProgram();
    final plan = buildWorkoutSavePlan(
      drafts: const [
        WorkoutEntryDraft(
          exerciseId: 'bench',
          sets: 3,
          reps: 8,
          weight: 80,
          programId: 'other_program',
          programDayId: 'day',
          programExerciseId: 'program_bench',
        ),
      ],
      userId: 'user',
      workoutDate: workoutDate,
      createdAt: createdAt,
      idFactory: sequentialIds(),
      activeProgram: program,
      activeProgramDay: program.currentDay,
      selectedDateIsToday: true,
    );

    expect(plan.bundles.single.setLogs, hasLength(3));
    expect(plan.savedCurrentProgramExerciseIds, isEmpty);
    expect(plan.shouldAdvanceProgram, isFalse);
  });
}
