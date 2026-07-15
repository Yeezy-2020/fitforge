import 'dart:async';

import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:fitforge/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('training program derived providers', () {
    test('distinguish an empty program list from a storage failure', () async {
      final emptyStore = _ControlledTrainingProgramStore();
      final emptyContainer = _container(emptyStore);
      addTearDown(emptyContainer.dispose);

      expect(
        await emptyContainer.read(activeTrainingProgramProvider.future),
        isNull,
      );
      expect(
        await emptyContainer.read(
          activeTrainingProgramForDateProvider(DateTime(2026, 7, 13)).future,
        ),
        isNull,
      );
      expect(
        await emptyContainer.read(
          workoutPrescriptionsForDateProvider(DateTime(2026, 7, 13)).future,
        ),
        isEmpty,
      );

      final storageError = const CorruptStorageDataException('bad payload');
      final failingStore = _ControlledTrainingProgramStore(
        readError: storageError,
      );
      final failingContainer = _container(failingStore);
      addTearDown(failingContainer.dispose);

      await expectLater(
        failingContainer.read(trainingProgramsProvider.future),
        throwsA(same(storageError)),
      );
      await expectLater(
        failingContainer.read(activeTrainingProgramProvider.future),
        throwsA(same(storageError)),
      );
      await expectLater(
        failingContainer.read(
          activeTrainingProgramForDateProvider(DateTime(2026, 7, 13)).future,
        ),
        throwsA(same(storageError)),
      );
      await expectLater(
        failingContainer.read(
          workoutPrescriptionsForDateProvider(DateTime(2026, 7, 13)).future,
        ),
        throwsA(same(storageError)),
      );

      expect(
        failingContainer.read(activeTrainingProgramProvider),
        isA<AsyncError<TrainingProgram?>>(),
      );
    });
  });

  group('TrainingProgramsNotifier user isolation', () {
    for (final mutation
        in <
          (
            String,
            String,
            Future<void> Function(TrainingProgramsNotifier, TrainingProgram),
          )
        >[
          (
            'save',
            'save:user-a',
            (notifier, program) =>
                notifier.save(_program(userId: 'user-a', id: 'replacement-a')),
          ),
          (
            'delete',
            'delete:user-a',
            (notifier, program) =>
                notifier.delete(program.id, expectedUserId: program.userId),
          ),
          (
            'setActive',
            'setActive:user-a',
            (notifier, program) => notifier.setActive(
              program.id,
              activatedAt: DateTime(2026, 7, 13),
              plannedCycleCount: 3,
              expectedUserId: program.userId,
            ),
          ),
          (
            'end',
            'end:user-a',
            (notifier, program) =>
                notifier.end(program.id, expectedUserId: program.userId),
          ),
        ]) {
      test(
        '${mutation.$1} does not publish user A data after switch',
        () async {
          final userAProgram = _program(userId: 'user-a', id: 'program-a');
          final userBProgram = _program(userId: 'user-b', id: 'program-b');
          final store = _ControlledTrainingProgramStore(
            programsByUser: {
              'user-a': [userAProgram],
              'user-b': [userBProgram],
            },
          );
          final container = _container(store);
          addTearDown(container.dispose);
          await container.read(trainingProgramsProvider.future);

          store.writeGate = Completer<void>();
          final operation = mutation.$3(
            container.read(trainingProgramsProvider.notifier),
            userAProgram,
          );
          expect(store.calls, contains(mutation.$2));

          container.read(currentUserIdProvider.notifier).state = 'user-b';
          final userBPrograms = await container.read(
            trainingProgramsProvider.future,
          );
          expect(userBPrograms.map((program) => program.userId), ['user-b']);

          store.writeGate!.complete();
          await operation;

          final state = container.read(trainingProgramsProvider);
          expect(state.requireValue.map((program) => program.userId), [
            'user-b',
          ]);
          expect(
            store.calls.where((call) => call.startsWith('${mutation.$1}:')),
            [mutation.$2],
          );
        },
      );
    }

    test('an in-flight mutation cannot publish after logout', () async {
      final userAProgram = _program(userId: 'user-a', id: 'program-a');
      final store = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [userAProgram],
        },
      );
      final container = _container(store);
      addTearDown(container.dispose);
      await container.read(trainingProgramsProvider.future);

      store.writeGate = Completer<void>();
      final operation = container
          .read(trainingProgramsProvider.notifier)
          .delete(userAProgram.id, expectedUserId: userAProgram.userId);
      expect(store.calls, contains('delete:user-a'));

      container.read(currentUserIdProvider.notifier).state = '';
      expect(await container.read(trainingProgramsProvider.future), isEmpty);

      store.writeGate!.complete();
      await operation;

      expect(container.read(trainingProgramsProvider).requireValue, isEmpty);
      expect(
        store.calls.where((call) => call == 'delete:user-a'),
        hasLength(1),
      );
    });

    test('build-scope token blocks an A to B to A stale publish', () async {
      final originalA = _program(userId: 'user-a', id: 'original-a');
      final replacementA = _program(userId: 'user-a', id: 'replacement-a');
      final userBProgram = _program(userId: 'user-b', id: 'program-b');
      final store = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [originalA],
          'user-b': [userBProgram],
        },
      );
      final container = _container(store);
      addTearDown(container.dispose);
      await container.read(trainingProgramsProvider.future);

      store.writeGate = Completer<void>();
      final operation = container
          .read(trainingProgramsProvider.notifier)
          .save(replacementA);

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await container.read(trainingProgramsProvider.future);
      container.read(currentUserIdProvider.notifier).state = 'user-a';
      final rebuiltA = await container.read(trainingProgramsProvider.future);
      expect(rebuiltA.map((program) => program.id), ['original-a']);

      store.writeGate!.complete();
      await operation;

      expect(
        container
            .read(trainingProgramsProvider)
            .requireValue
            .map((program) => program.id),
        ['original-a'],
      );
      expect(store.programsByUser['user-a']!.map((program) => program.id), [
        'replacement-a',
      ]);
    });

    test('advanceDay aborts before writing after an account switch', () async {
      final userAProgram = _program(
        userId: 'user-a',
        id: 'program-a',
        active: true,
      );
      final store = _ControlledTrainingProgramStore(
        programsByUser: {
          'user-a': [userAProgram],
          'user-b': [_program(userId: 'user-b', id: 'program-b')],
        },
      );
      final container = _container(store);
      addTearDown(container.dispose);
      await container.read(trainingProgramsProvider.future);

      store.activeReadGate = Completer<void>();
      final operation = container
          .read(trainingProgramsProvider.notifier)
          .advanceDay();
      expect(store.calls, contains('getActive:user-a'));

      container.read(currentUserIdProvider.notifier).state = 'user-b';
      await container.read(trainingProgramsProvider.future);
      store.activeReadGate!.complete();
      await operation;

      expect(store.calls.where((call) => call.startsWith('save:')), isEmpty);
      expect(
        container
            .read(trainingProgramsProvider)
            .requireValue
            .map((program) => program.userId),
        ['user-b'],
      );
    });

    test(
      'advanceDay rejects a mismatched expected user before reading',
      () async {
        final store = _ControlledTrainingProgramStore(
          programsByUser: {
            'user-a': [
              _program(userId: 'user-a', id: 'program-a', active: true),
            ],
          },
        );
        final container = _container(store);
        addTearDown(container.dispose);
        await container.read(trainingProgramsProvider.future);

        await container
            .read(trainingProgramsProvider.notifier)
            .advanceDay(expectedUserId: 'user-b');

        expect(
          store.calls.where((call) => call.startsWith('getActive:')),
          isEmpty,
        );
        expect(store.calls.where((call) => call.startsWith('save:')), isEmpty);
      },
    );
  });
}

ProviderContainer _container(_ControlledTrainingProgramStore store) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'user-a'),
      trainingProgramStoreProvider.overrideWith((ref) => store),
    ],
  );
}

TrainingProgram _program({
  required String userId,
  required String id,
  bool active = false,
}) {
  final timestamp = DateTime.utc(2026, 7, 13);
  return TrainingProgram(
    id: id,
    userId: userId,
    name: id,
    days: const [ProgramDay(id: 'day-1', name: 'Day 1')],
    active: active,
    activatedAt: active ? timestamp : null,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _ControlledTrainingProgramStore implements TrainingProgramStore {
  final Map<String, List<TrainingProgram>> programsByUser;
  final Object? readError;
  final List<String> calls = [];
  Completer<void>? writeGate;
  Completer<void>? activeReadGate;

  _ControlledTrainingProgramStore({
    Map<String, List<TrainingProgram>>? programsByUser,
    this.readError,
  }) : programsByUser = {
         for (final entry in (programsByUser ?? {}).entries)
           entry.key: List<TrainingProgram>.from(entry.value),
       };

  @override
  Future<List<TrainingProgram>> getTrainingPrograms(String userId) async {
    final error = readError;
    if (error != null) throw error;
    return List<TrainingProgram>.from(programsByUser[userId] ?? const []);
  }

  @override
  Future<void> saveTrainingProgram(
    String userId,
    TrainingProgram program,
  ) async {
    calls.add('save:$userId');
    await _waitForWriteGate();
    programsByUser[userId] = [program];
  }

  @override
  Future<void> deleteTrainingProgram(String userId, String programId) async {
    calls.add('delete:$userId');
    await _waitForWriteGate();
    programsByUser[userId] = [
      for (final program in programsByUser[userId] ?? const [])
        if (program.id != programId) program,
    ];
  }

  @override
  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) async {
    calls.add('setActive:$userId');
    await _waitForWriteGate();
  }

  @override
  Future<void> endTrainingProgram(String userId, String programId) async {
    calls.add('end:$userId');
    await _waitForWriteGate();
  }

  @override
  Future<TrainingProgram?> getActiveTrainingProgram(String userId) async {
    calls.add('getActive:$userId');
    final gate = activeReadGate;
    if (gate != null) await gate.future;
    return (programsByUser[userId] ?? const [])
        .where((program) => program.active)
        .firstOrNull;
  }

  Future<void> _waitForWriteGate() async {
    final gate = writeGate;
    if (gate != null) await gate.future;
  }
}
