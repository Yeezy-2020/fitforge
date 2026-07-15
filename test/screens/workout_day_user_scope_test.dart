import 'dart:async';

import 'package:fitforge/core/localization/l10n.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/exercise.dart';
import 'package:fitforge/data/models/food.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/user_profile.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:fitforge/features/workout/screens/workout_day_screen.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:fitforge/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'account switch completes all A local bundles and stops later work',
    (tester) async {
      final writeStore = _ControlledWorkoutLogWriteStore()
        ..addWorkoutGate = Completer<void>();
      final remoteWriter = _ControlledWorkoutLogRemoteWriter();
      final trainingStore = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      );
      final container = _container(
        writeStore: writeStore,
        remoteWriter: remoteWriter,
        trainingStore: trainingStore,
      );
      addTearDown(container.dispose);
      await _pumpWorkoutDay(tester, container);
      await tester.tap(find.widgetWithText(TextButton, 'Add').first);
      await tester.tap(find.widgetWithText(TextButton, 'Add').first);
      await tester.pump();
      await tester.tap(find.text('Save (2)'));
      await tester.pump();

      expect(writeStore.calls, ['addWorkout:user-a']);
      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await tester.pump();
      writeStore.addWorkoutGate!.complete();
      await tester.pumpAndSettle();

      expect(writeStore.calls, [
        'addWorkout:user-a',
        'saveSets:user-a',
        'addWorkout:user-a',
        'saveSets:user-a',
      ]);
      expect(
        writeStore.calls.where((call) => call.contains('user-b')),
        isEmpty,
      );
      expect(
        trainingStore.calls.where((call) => call.startsWith('getActive:')),
        isEmpty,
      );
      expect(remoteWriter.calls, isEmpty);
      expect(container.read(workoutCacheProvider), isEmpty);
      expect(container.read(workoutLogCacheProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A draft is cleared before B can save it', (tester) async {
    final writeStore = _ControlledWorkoutLogWriteStore();
    final container = _container(
      writeStore: writeStore,
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      ),
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();
    expect(find.text('Save (1)'), findsOneWidget);

    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.tap(find.text('Save (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Save (1)'), findsNothing);
    expect(writeStore.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A to B to A never restores the old A draft', (tester) async {
    final writeStore = _ControlledWorkoutLogWriteStore();
    final container = _container(
      writeStore: writeStore,
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      ),
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();

    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.pump();
    container.read(currentUserIdProvider.notifier).state = 'user-a';
    await tester.pumpAndSettle();

    expect(find.text('Save (1)'), findsNothing);
    expect(writeStore.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old edit and delete dialogs cannot mutate a new scope draft', (
    tester,
  ) async {
    final writeStore = _ControlledWorkoutLogWriteStore();
    final container = _container(
      writeStore: writeStore,
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
          'user-b': [_program('user-b')],
        },
      ),
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);

    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();
    await tester.tap(find.textContaining('1x8'));
    await tester.pumpAndSettle();
    final editFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(editFields.at(0), '9');
    await tester.enterText(editFields.at(1), '99');

    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.pump();
    final addForB = find
        .widgetWithText(TextButton, 'Add', skipOffstage: false)
        .first;
    tester.widget<TextButton>(addForB).onPressed!();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('9x99'), findsNothing);
    expect(find.text('Save (1)'), findsOneWidget);

    container.read(currentUserIdProvider.notifier).state = 'user-a';
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.pump();
    final replacementAdd = find
        .widgetWithText(TextButton, 'Add', skipOffstage: false)
        .first;
    tester.widget<TextButton>(replacementAdd).onPressed!();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Save (1)'), findsOneWidget);
    expect(writeStore.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account switch during remote write never sends A data as user B',
    (tester) async {
      final writeStore = _ControlledWorkoutLogWriteStore();
      final remoteWriter = _ControlledWorkoutLogRemoteWriter()
        ..writeGate = Completer<void>();
      final trainingStore = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      );
      final container = _container(
        writeStore: writeStore,
        remoteWriter: remoteWriter,
        trainingStore: trainingStore,
      );
      addTearDown(container.dispose);
      await _pumpWorkoutDay(tester, container);
      await _addProgramDraftAndSave(tester);
      await _pumpUntil(tester, () => remoteWriter.calls.isNotEmpty);

      expect(remoteWriter.calls, ['remote:user-a:user-a']);
      expect(
        trainingStore.calls.where((call) => call == 'save:user-a'),
        hasLength(1),
      );
      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await tester.pump();
      remoteWriter.writeGate!.complete();
      await tester.pumpAndSettle();

      expect(
        trainingStore.calls.where((call) => call == 'save:user-b'),
        isEmpty,
      );
      expect(
        writeStore.calls.where((call) => call.startsWith('unsynced:')),
        isEmpty,
      );
      expect(container.read(workoutCacheProvider), isEmpty);
      expect(container.read(workoutLogCacheProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposed workout save does not read a disposed ref', (
    tester,
  ) async {
    final writeStore = _ControlledWorkoutLogWriteStore()
      ..addWorkoutGate = Completer<void>();
    final container = _container(
      writeStore: writeStore,
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      ),
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);
    await _addProgramDraftAndSave(tester);
    expect(writeStore.calls, ['addWorkout:user-a']);

    await tester.pumpWidget(const SizedBox.shrink());
    writeStore.addWorkoutGate!.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid save taps run one log, set, and program advance chain', (
    tester,
  ) async {
    final writeStore = _ControlledWorkoutLogWriteStore()
      ..addWorkoutGate = Completer<void>();
    final remoteWriter = _ControlledWorkoutLogRemoteWriter()
      ..writeGate = Completer<void>();
    final trainingStore = _ControlledTrainingProgramStore(
      programsByUser: {
        'user-a': [_program('user-a')],
      },
    );
    final container = _container(
      writeStore: writeStore,
      remoteWriter: remoteWriter,
      trainingStore: trainingStore,
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);

    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();
    final saveButton = find.widgetWithText(TextButton, 'Save (1)');
    await tester.tap(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(tester.widget<TextButton>(saveButton).onPressed, isNull);
    await _pumpUntil(
      tester,
      () => writeStore.calls
          .where((call) => call == 'addWorkout:user-a')
          .isNotEmpty,
    );
    expect(
      writeStore.calls.where((call) => call == 'addWorkout:user-a'),
      hasLength(1),
    );

    writeStore.addWorkoutGate!.complete();
    await _pumpUntil(tester, () => remoteWriter.calls.isNotEmpty);

    expect(
      writeStore.calls.where((call) => call == 'addWorkout:user-a'),
      hasLength(1),
    );
    expect(
      writeStore.calls.where((call) => call == 'saveSets:user-a'),
      hasLength(1),
    );
    expect(
      trainingStore.calls.where((call) => call == 'save:user-a'),
      hasLength(1),
    );
    expect(remoteWriter.calls, ['remote:user-a:user-a']);

    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.pump();
    remoteWriter.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid rest-day completion taps advance only once', (
    tester,
  ) async {
    final advanceGate = Completer<void>();
    final trainingStore = _ControlledTrainingProgramStore(
      programsByUser: {
        'user-a': [_restProgram('user-a')],
      },
    )..activeProgramGate = advanceGate;
    final container = _container(
      writeStore: _ControlledWorkoutLogWriteStore(),
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: trainingStore,
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);

    final completeButton = find.widgetWithText(TextButton, 'Complete rest day');
    final initialSize = tester.getSize(completeButton);
    await tester.tap(completeButton);
    await tester.tap(completeButton);
    await tester.pump();

    expect(tester.widget<TextButton>(completeButton).onPressed, isNull);
    expect(tester.getSize(completeButton), initialSize);
    expect(
      trainingStore.calls.where((call) => call == 'getActive:user-a'),
      hasLength(1),
    );

    advanceGate.complete();
    await tester.pumpAndSettle();

    expect(
      trainingStore.calls.where((call) => call == 'getActive:user-a'),
      hasLength(1),
    );
    expect(
      trainingStore.calls.where((call) => call == 'save:user-a'),
      hasLength(1),
    );
    expect(tester.widget<TextButton>(completeButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed set write freezes drafts and retries fixed IDs with one advance',
    (tester) async {
      final writeStore = _ControlledWorkoutLogWriteStore()
        ..setWriteFailuresRemaining = 1;
      final remoteWriter = _ControlledWorkoutLogRemoteWriter()
        ..writeGate = Completer<void>();
      final trainingStore = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      );
      final container = _container(
        writeStore: writeStore,
        remoteWriter: remoteWriter,
        trainingStore: trainingStore,
      );
      addTearDown(container.dispose);
      await _pumpWorkoutDay(tester, container);
      await _addProgramDraftAndSave(tester);
      await _pumpUntil(tester, () => writeStore.setLogBatches.length == 1);
      await _pumpUntil(tester, () {
        final save = find.widgetWithText(TextButton, 'Save (1)');
        return save.evaluate().isNotEmpty &&
            tester.widget<TextButton>(save).onPressed != null;
      });

      final firstWorkoutId = writeStore.workoutLogs.single.id;
      final firstSetIds = writeStore.setLogBatches.single
          .map((log) => log.id)
          .toList();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Add').first)
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Clear'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.bookmark_border),
            )
            .onPressed,
        isNull,
      );
      expect(
        trainingStore.calls.where((call) => call == 'save:user-a'),
        isEmpty,
      );

      await tester.tap(find.text('Save (1)'));
      await tester.pump();
      await _pumpUntil(tester, () => remoteWriter.calls.isNotEmpty);

      expect(writeStore.workoutLogs, hasLength(2));
      expect(writeStore.workoutLogs.map((log) => log.id), [
        firstWorkoutId,
        firstWorkoutId,
      ]);
      expect(writeStore.setLogBatches, hasLength(2));
      expect(writeStore.setLogBatches.last.map((log) => log.id), firstSetIds);
      expect(
        trainingStore.calls.where((call) => call == 'save:user-a'),
        hasLength(1),
      );

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await tester.pump();
      remoteWriter.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account switch cancels saving an old draft as a template', (
    tester,
  ) async {
    final container = _container(
      writeStore: _ControlledWorkoutLogWriteStore(),
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [_program('user-a')],
        },
      ),
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);
    await tester.tap(find.widgetWithText(TextButton, 'Add').first);
    await tester.pump();

    await tester.tap(find.byTooltip('Save as template'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Old account draft');
    container.read(currentUserIdProvider.notifier).state = 'user-b';
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await AppDatabase.instance.getTemplates('user-a'), isEmpty);
    expect(await AppDatabase.instance.getTemplates('user-b'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('program retry invalidates the root failed provider', (
    tester,
  ) async {
    final trainingStore = _ControlledTrainingProgramStore(
      readError: StateError('storage unavailable'),
    );
    final container = _container(
      writeStore: _ControlledWorkoutLogWriteStore(),
      remoteWriter: _ControlledWorkoutLogRemoteWriter(),
      trainingStore: trainingStore,
    );
    addTearDown(container.dispose);
    await _pumpWorkoutDay(tester, container);

    expect(find.text('Failed to load'), findsOneWidget);
    final readsBeforeRetry = trainingStore.programReadCount;
    trainingStore.readError = null;
    await tester.tap(find.byTooltip('Failed to load'));
    await tester.pumpAndSettle();

    expect(trainingStore.programReadCount, greaterThan(readsBeforeRetry));
    expect(find.text('Failed to load'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _container({
  required _ControlledWorkoutLogWriteStore writeStore,
  required _ControlledWorkoutLogRemoteWriter remoteWriter,
  required _ControlledTrainingProgramStore trainingStore,
}) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'user-a'),
      localeProvider.overrideWith((ref) => AppLocale.en),
      trainingWeightUnitProvider.overrideWith((ref) => WeightUnit.kg),
      exerciseListProvider.overrideWith(_EmptyExerciseListNotifier.new),
      progressionRulesProvider.overrideWith(_EmptyProgressionRulesNotifier.new),
      userDataRemoteProvider.overrideWith((ref) => _NoopUserDataRemote()),
      workoutLogWriteStoreProvider.overrideWith((ref) => writeStore),
      workoutLogRemoteWriterProvider.overrideWith((ref) => remoteWriter),
      trainingProgramStoreProvider.overrideWith((ref) => trainingStore),
    ],
  );
}

Future<void> _pumpWorkoutDay(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: WorkoutDayScreen(date: _today())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _addProgramDraftAndSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Add').first);
  await tester.pump();
  expect(find.text('Save (1)'), findsOneWidget);
  await tester.tap(find.text('Save (1)'));
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt += 1) {
    await tester.pump();
  }
  expect(condition(), isTrue);
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

TrainingProgram _program(String userId) {
  final now = _today();
  return TrainingProgram(
    id: 'program-$userId',
    userId: userId,
    name: 'Program $userId',
    active: true,
    activatedAt: now,
    createdAt: now,
    updatedAt: now,
    days: const [
      ProgramDay(
        id: 'day-1',
        name: 'Day 1',
        exercises: [
          ProgramExercise(
            id: 'slot-1',
            exerciseId: 'exercise-1',
            targetSets: 1,
            minReps: 8,
            maxReps: 8,
            startingWeightKg: 50,
          ),
        ],
      ),
    ],
  );
}

TrainingProgram _restProgram(String userId) {
  final now = _today();
  return TrainingProgram(
    id: 'rest-program-$userId',
    userId: userId,
    name: 'Rest Program $userId',
    active: true,
    activatedAt: now,
    createdAt: now,
    updatedAt: now,
    days: const [
      ProgramDay(id: 'rest-day-1', name: 'Rest', kind: DayKind.rest),
    ],
  );
}

class _EmptyExerciseListNotifier extends ExerciseListNotifier {
  @override
  Future<List<Exercise>> build() async => [];
}

class _EmptyProgressionRulesNotifier extends ProgressionRulesNotifier {
  @override
  Future<List<ProgressionRule>> build() async => [];
}

class _ControlledWorkoutLogWriteStore implements WorkoutLogWriteStore {
  final List<String> calls = [];
  final List<WorkoutLog> workoutLogs = [];
  final List<List<WorkoutSetLog>> setLogBatches = [];
  Completer<void>? addWorkoutGate;
  int setWriteFailuresRemaining = 0;

  @override
  Future<void> addWorkoutLog(String userId, WorkoutLog log) async {
    calls.add('addWorkout:$userId');
    workoutLogs.add(log);
    final gate = addWorkoutGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> saveWorkoutSetLogs(
    String userId,
    List<WorkoutSetLog> setLogs,
  ) async {
    calls.add('saveSets:$userId');
    setLogBatches.add(List<WorkoutSetLog>.unmodifiable(setLogs));
    if (setWriteFailuresRemaining > 0) {
      setWriteFailuresRemaining -= 1;
      throw StateError('set write failed');
    }
  }

  @override
  Future<void> addUnsyncedWorkout(String userId, WorkoutLog log) async {
    calls.add('unsynced:$userId');
  }
}

class _ControlledWorkoutLogRemoteWriter implements WorkoutLogRemoteWriter {
  final List<String> calls = [];
  Completer<void>? writeGate;

  @override
  Future<void> addWorkoutLog(
    WorkoutLog log, {
    required String expectedUserId,
  }) async {
    calls.add('remote:$expectedUserId:${log.userId}');
    final gate = writeGate;
    if (gate != null) await gate.future;
  }
}

class _ControlledTrainingProgramStore implements TrainingProgramStore {
  final Map<String, List<TrainingProgram>> programsByUser;
  final List<String> calls = [];
  Object? readError;
  int programReadCount = 0;
  Completer<void>? activeProgramGate;

  _ControlledTrainingProgramStore({
    Map<String, List<TrainingProgram>>? programsByUser,
    this.readError,
  }) : programsByUser = {
         for (final entry in (programsByUser ?? {}).entries)
           entry.key: List<TrainingProgram>.from(entry.value),
       };

  @override
  Future<List<TrainingProgram>> getTrainingPrograms(String userId) async {
    programReadCount += 1;
    final error = readError;
    if (error != null) throw error;
    return List<TrainingProgram>.from(programsByUser[userId] ?? const []);
  }

  @override
  Future<TrainingProgram?> getActiveTrainingProgram(String userId) async {
    calls.add('getActive:$userId');
    final gate = activeProgramGate;
    if (gate != null) await gate.future;
    return (programsByUser[userId] ?? const [])
        .where((program) => program.active)
        .firstOrNull;
  }

  @override
  Future<void> saveTrainingProgram(
    String userId,
    TrainingProgram program,
  ) async {
    calls.add('save:$userId');
    programsByUser[userId] = [program];
  }

  @override
  Future<void> deleteTrainingProgram(String userId, String programId) async {}

  @override
  Future<void> endTrainingProgram(String userId, String programId) async {}

  @override
  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) async {}
}

class _NoopUserDataRemote implements UserDataRemote {
  @override
  Future<List<DietLog>> getDietLogs(String userId, DateTime date) async => [];

  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<List<Food>> getPublicFoods(String userId) async => [];

  @override
  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async =>
      [];

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async => [];

  @override
  Future<void> upsertProfile(String userId, UserProfile profile) async {}
}
