import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/features/workout/screens/program_detail_screen.dart';
import 'package:fitforge/features/workout/screens/training_programs_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('A to B to A invalidates a pending create-program dialog', (
    tester,
  ) async {
    final store = _RecordingTrainingProgramStore();
    final container = _container(store);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container, const TrainingProgramsScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Create blank program'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await _switchUser(tester, container, 'user-b');
    await _switchUser(tester, container, 'user-a');
    await tester.tap(find.widgetWithText(FilledButton, 'Create program'));
    await tester.pumpAndSettle();

    expect(store.savedPrograms, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A to B to A invalidates a pending program-detail edit', (
    tester,
  ) async {
    final program = _program('user-a');
    final store = _RecordingTrainingProgramStore(
      programsByUser: {
        'user-a': [program],
      },
    );
    final container = _container(store);
    addTearDown(container.dispose);
    await _pumpScreen(
      tester,
      container,
      ProgramDetailScreen(programId: program.id),
    );

    await tester.tap(find.byTooltip('Edit program settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await _switchUser(tester, container, 'user-b');
    await _switchUser(tester, container, 'user-a');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(store.savedPrograms, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _container(_RecordingTrainingProgramStore store) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'user-a'),
      localeProvider.overrideWith((ref) => AppLocale.en),
      trainingProgramStoreProvider.overrideWith((ref) => store),
      exerciseListProvider.overrideWith(_EmptyExerciseListNotifier.new),
    ],
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _switchUser(
  WidgetTester tester,
  ProviderContainer container,
  String userId,
) async {
  container.read(currentUserIdProvider.notifier).state = userId;
  await tester.pumpAndSettle();
}

TrainingProgram _program(String userId) {
  final now = DateTime.utc(2026, 7, 13);
  return TrainingProgram(
    id: 'program-$userId',
    userId: userId,
    name: 'Program $userId',
    createdAt: now,
    updatedAt: now,
  );
}

class _EmptyExerciseListNotifier extends ExerciseListNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

class _RecordingTrainingProgramStore implements TrainingProgramStore {
  final Map<String, List<TrainingProgram>> programsByUser;
  final List<TrainingProgram> savedPrograms = [];

  _RecordingTrainingProgramStore({
    Map<String, List<TrainingProgram>>? programsByUser,
  }) : programsByUser = {
         for (final entry in (programsByUser ?? const {}).entries)
           entry.key: List<TrainingProgram>.from(entry.value),
       };

  @override
  Future<List<TrainingProgram>> getTrainingPrograms(String userId) async {
    return List<TrainingProgram>.from(programsByUser[userId] ?? const []);
  }

  @override
  Future<void> saveTrainingProgram(
    String userId,
    TrainingProgram program,
  ) async {
    savedPrograms.add(program);
    programsByUser[userId] = [program];
  }

  @override
  Future<void> deleteTrainingProgram(String userId, String programId) async {}

  @override
  Future<void> endTrainingProgram(String userId, String programId) async {}

  @override
  Future<TrainingProgram?> getActiveTrainingProgram(String userId) async {
    return (programsByUser[userId] ?? const [])
        .where((program) => program.active)
        .firstOrNull;
  }

  @override
  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) async {}
}
