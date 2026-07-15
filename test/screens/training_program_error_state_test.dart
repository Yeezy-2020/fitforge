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
  group('training program load errors', () {
    testWidgets('program detail hides internal errors and retries in Chinese', (
      tester,
    ) async {
      final store = _FailOnceTrainingProgramStore([
        _program(id: 'program-1', name: '恢复后的计划'),
      ]);

      await tester.pumpWidget(
        _programApp(
          store: store,
          child: const ProgramDetailScreen(programId: 'program-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.textContaining(_internalError), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(store.readCount, 2);
      expect(find.text('加载失败'), findsNothing);
      expect(find.text('恢复后的计划'), findsOneWidget);
    });

    testWidgets('program list hides internal errors and retries in Chinese', (
      tester,
    ) async {
      final store = _FailOnceTrainingProgramStore(const []);

      await tester.pumpWidget(
        _programApp(store: store, child: const TrainingProgramsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.textContaining(_internalError), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(store.readCount, 2);
      expect(find.text('加载失败'), findsNothing);
      expect(find.text('暂无训练计划'), findsOneWidget);
    });
  });
}

const _internalError = 'private-storage-payload';

Widget _programApp({
  required TrainingProgramStore store,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'test-user'),
      localeProvider.overrideWith((ref) => AppLocale.zh),
      trainingProgramStoreProvider.overrideWith((ref) => store),
      exerciseListProvider.overrideWith(_EmptyExerciseListNotifier.new),
    ],
    child: MaterialApp(home: child),
  );
}

TrainingProgram _program({required String id, required String name}) {
  final now = DateTime.utc(2026, 7, 13);
  return TrainingProgram(
    id: id,
    userId: 'test-user',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

class _EmptyExerciseListNotifier extends ExerciseListNotifier {
  @override
  Future<List<Exercise>> build() async => const [];
}

class _FailOnceTrainingProgramStore implements TrainingProgramStore {
  final List<TrainingProgram> programs;
  int readCount = 0;

  _FailOnceTrainingProgramStore(this.programs);

  @override
  Future<List<TrainingProgram>> getTrainingPrograms(String userId) async {
    readCount += 1;
    if (readCount == 1) throw StateError(_internalError);
    return programs;
  }

  @override
  Future<void> deleteTrainingProgram(String userId, String programId) {
    throw UnsupportedError('not used');
  }

  @override
  Future<void> endTrainingProgram(String userId, String programId) {
    throw UnsupportedError('not used');
  }

  @override
  Future<TrainingProgram?> getActiveTrainingProgram(String userId) {
    throw UnsupportedError('not used');
  }

  @override
  Future<void> saveTrainingProgram(String userId, TrainingProgram program) {
    throw UnsupportedError('not used');
  }

  @override
  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) {
    throw UnsupportedError('not used');
  }
}
