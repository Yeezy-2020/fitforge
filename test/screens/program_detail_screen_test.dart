import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:fitforge/features/workout/screens/program_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  const userId = 'test';
  const programId = 'program_detail_smoke';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> seedProgram() async {
    final createdAt = DateTime(2025, 6, 1);
    final program = TrainingProgram(
      id: programId,
      userId: userId,
      name: 'Split Smoke Program',
      createdAt: createdAt,
      updatedAt: createdAt,
      days: const [
        ProgramDay(
          id: 'day_upper_a',
          name: 'Upper A',
          exercises: [
            ProgramExercise(
              id: 'program_bench_press',
              exerciseId: 'ex_bench_press',
              targetSets: 4,
              minReps: 6,
              maxReps: 10,
              startingWeightKg: 60,
            ),
          ],
        ),
      ],
    );

    await AppDatabase.instance.saveExercises(userId, [testExercises.first]);
    await AppDatabase.instance.saveTrainingPrograms(userId, [program]);
  }

  testWidgets('renders program parts and opens the day editor', (tester) async {
    await seedProgram();
    await tester.pumpWidget(
      testApp(child: const ProgramDetailScreen(programId: programId)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Split Smoke Program'), findsOneWidget);
    expect(find.text('Day 1: Upper A'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.textContaining('4 sets'), findsOneWidget);
    expect(find.textContaining('Double progression +2.5 kg'), findsOneWidget);
    expect(find.text('Add exercise'), findsOneWidget);

    final editDayButton = find.byTooltip('Edit day');
    expect(editDayButton, findsOneWidget);
    await tester.ensureVisible(editDayButton);
    await tester.tap(editDayButton);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Edit day'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Day 1: Upper A'), findsOneWidget);
  });
}
