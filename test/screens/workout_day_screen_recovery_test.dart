import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:fitforge/features/workout/screens/workout_day_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  const userId = 'test';
  const programId = 'program_recovery';
  const programDayId = 'day_recovery';
  const programExerciseId = 'pe_bench';
  const exerciseId = 'ex_bench_press';
  final selectedDate = DateTime(2025, 6, 20);
  final staleDate = selectedDate.subtract(const Duration(days: 8));

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  TrainingProgram recoveryProgram({
    List<ProgramExercise> exercises = const [
      ProgramExercise(
        id: programExerciseId,
        exerciseId: exerciseId,
        targetSets: 3,
        minReps: 8,
        maxReps: 12,
        startingWeightKg: 40,
      ),
    ],
  }) {
    final createdAt = DateTime(2025, 6, 1);
    return TrainingProgram(
      id: programId,
      userId: userId,
      name: 'Recovery Program',
      active: true,
      activatedAt: selectedDate,
      createdAt: createdAt,
      updatedAt: createdAt,
      days: [
        ProgramDay(id: programDayId, name: 'Bench Day', exercises: exercises),
      ],
    );
  }

  Future<void> seedRecoveryPrescription() async {
    final database = AppDatabase.instance;
    await database.saveTrainingPrograms(userId, [recoveryProgram()]);
    await database.addWorkoutLog(
      userId,
      WorkoutLog(
        id: 'log_stale_bench',
        userId: userId,
        exerciseId: exerciseId,
        date: staleDate,
        sets: 4,
        reps: 12,
        weightKg: 82.5,
      ),
    );
    await database.saveWorkoutSetLogs(userId, const [
      WorkoutSetLog(
        id: 'set_stale_bench',
        workoutLogId: 'log_stale_bench',
        programId: programId,
        programExerciseId: programExerciseId,
        setIndex: 0,
        reps: 12,
        weightKg: 82.5,
        completed: true,
      ),
    ]);
  }

  Future<void> seedMixedRecoveryPrescriptions() async {
    final database = AppDatabase.instance;
    await database.saveTrainingPrograms(userId, [
      recoveryProgram(
        exercises: const [
          ProgramExercise(
            id: programExerciseId,
            exerciseId: exerciseId,
            targetSets: 3,
            minReps: 8,
            maxReps: 12,
            startingWeightKg: 40,
            sortOrder: 0,
          ),
          ProgramExercise(
            id: 'pe_squat',
            exerciseId: 'ex_squat',
            targetSets: 3,
            minReps: 8,
            maxReps: 12,
            startingWeightKg: 100,
            sortOrder: 1,
          ),
        ],
      ),
    ]);
    await database.addWorkoutLog(
      userId,
      WorkoutLog(
        id: 'log_stale_bench',
        userId: userId,
        exerciseId: exerciseId,
        date: staleDate,
        sets: 4,
        reps: 12,
        weightKg: 82.5,
      ),
    );
    await database.addWorkoutLog(
      userId,
      WorkoutLog(
        id: 'log_recent_squat',
        userId: userId,
        exerciseId: 'ex_squat',
        date: selectedDate.subtract(const Duration(days: 3)),
        sets: 3,
        reps: 10,
        weightKg: 100,
      ),
    );
    await database.saveWorkoutSetLogs(userId, const [
      WorkoutSetLog(
        id: 'set_stale_bench',
        workoutLogId: 'log_stale_bench',
        programId: programId,
        programExerciseId: programExerciseId,
        setIndex: 0,
        reps: 12,
        weightKg: 82.5,
        completed: true,
      ),
      WorkoutSetLog(
        id: 'set_recent_squat',
        workoutLogId: 'log_recent_squat',
        programId: programId,
        programExerciseId: 'pe_squat',
        setIndex: 0,
        reps: 10,
        weightKg: 100,
        completed: true,
      ),
    ]);
  }

  Future<void> pumpWorkoutDay(
    WidgetTester tester, {
    Future<void> Function()? seed,
  }) async {
    await (seed ?? seedRecoveryPrescription)();
    await tester.pumpWidget(
      testApp(child: WorkoutDayScreen(date: selectedDate)),
    );
    await tester.pumpAndSettle();
  }

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  group('WorkoutDayScreen long-gap recovery UI', () {
    testWidgets('row-level recovery prompt can add the last logged values', (
      tester,
    ) async {
      await pumpWorkoutDay(tester);

      expect(find.textContaining('Last trained 8 days ago'), findsOneWidget);

      await tester.tap(find.text('Use last time'));
      await tester.pumpAndSettle();

      expect(find.text('Pending: 1 sets'), findsOneWidget);
      expect(find.textContaining('4x12 82.5 kg'), findsOneWidget);
      expect(find.textContaining('4x8 85.0 kg'), findsNothing);
    });

    testWidgets('Add all can keep planned values after the break dialog', (
      tester,
    ) async {
      await pumpWorkoutDay(tester);

      await tester.tap(find.text('Add all'));
      await tester.pumpAndSettle();

      expect(find.text('Resume after break?'), findsOneWidget);
      expect(
        find.textContaining('1 planned exercises have been idle'),
        findsOneWidget,
      );

      await tester.tap(dialogText('Use plan'));
      await tester.pumpAndSettle();

      expect(find.text('Pending: 1 sets'), findsOneWidget);
      expect(find.textContaining('4x8 85.0 kg'), findsOneWidget);
      expect(find.textContaining('4x12 82.5 kg'), findsNothing);
    });

    testWidgets('Add all can use last logged values after the break dialog', (
      tester,
    ) async {
      await pumpWorkoutDay(tester);

      await tester.tap(find.text('Add all'));
      await tester.pumpAndSettle();

      expect(find.text('Resume after break?'), findsOneWidget);

      await tester.tap(dialogText('Use last time'));
      await tester.pumpAndSettle();

      expect(find.text('Pending: 1 sets'), findsOneWidget);
      expect(find.textContaining('4x12 82.5 kg'), findsOneWidget);
      expect(find.textContaining('4x8 85.0 kg'), findsNothing);
    });

    testWidgets(
      'Add all uses last logged values only for stale prescriptions',
      (tester) async {
        await pumpWorkoutDay(tester, seed: seedMixedRecoveryPrescriptions);

        await tester.tap(find.text('Add all'));
        await tester.pumpAndSettle();

        expect(find.text('Resume after break?'), findsOneWidget);
        expect(
          find.textContaining('1 planned exercises have been idle'),
          findsOneWidget,
        );

        await tester.tap(dialogText('Use last time'));
        await tester.pumpAndSettle();

        expect(find.text('Pending: 2 sets'), findsOneWidget);
        expect(find.textContaining('4x12 82.5 kg'), findsOneWidget);
        expect(find.textContaining('3x11 100.0 kg'), findsOneWidget);
        expect(find.textContaining('3x10 100.0 kg'), findsNothing);
      },
    );
  });
}
