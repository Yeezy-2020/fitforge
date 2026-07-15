import 'dart:async';
import 'dart:convert';

import 'package:fitforge/core/services/training_sync.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _storage = FlutterSecureStorage();
const _user = 'owner';
const _workoutId = '550e8400-e29b-41d4-a716-446655440000';

void main() {
  late AppDatabase database;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    database = AppDatabase.forTesting(trainingSyncEnabled: true);
  });

  test(
    'same entity compacts to latest operation and ack is tokenized',
    () async {
      await database.saveTrainingProgram(_user, _program(name: 'First'));
      final first = (await database.getTrainingSyncOutbox(_user)).single;

      await database.saveTrainingProgram(_user, _program(name: 'Second'));
      final second = (await database.getTrainingSyncOutbox(_user)).single;
      expect(second.token, isNot(first.token));
      expect(second.decodeProgram().name, 'Second');

      await database.acknowledgeTrainingSyncMutation(
        _user,
        domain: first.domain,
        entityId: first.entityId,
        token: first.token,
      );
      expect(
        (await database.getTrainingSyncOutbox(_user)).single.token,
        second.token,
      );

      await database.deleteTrainingProgram(_user, second.entityId);
      final deletion = (await database.getTrainingSyncOutbox(_user)).single;
      expect(deletion.operation, TrainingSyncOperation.delete);
      expect(deletion.payload, isNull);
    },
  );

  test(
    'outbox is user isolated, versioned, and future versions fail closed',
    () async {
      await database.saveTrainingProgram('user-a', _program(userId: 'user-a'));
      await database.saveTrainingProgram('user-b', _program(userId: 'user-b'));

      expect(
        (await database.getTrainingSyncOutbox('user-a')).single.userId,
        'user-a',
      );
      expect(
        (await database.getTrainingSyncOutbox('user-b')).single.userId,
        'user-b',
      );
      final raw = await _storage.read(key: 'user-a:training_sync_outbox');
      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      expect(envelope['schemaVersion'], 1);
      expect(envelope['userId'], 'user-a');

      const futureRaw = '{"schemaVersion":99,"userId":"future","data":[]}';
      FlutterSecureStorage.setMockInitialValues({
        'future:training_sync_outbox': futureRaw,
      });
      await expectLater(
        database.saveTrainingProgram(
          'future',
          _program(userId: 'future', id: 'future-program'),
        ),
        throwsA(isA<UnsupportedStorageVersionException>()),
      );
      expect(
        await _storage.read(key: 'future:training_sync_outbox'),
        futureRaw,
      );
      expect(await _storage.read(key: 'future:training_programs'), isNull);
    },
  );

  test(
    'workout delete cascades local sets and creates both tombstones',
    () async {
      await database.addWorkoutLog(_user, _workout());
      await database.saveWorkoutSetLogs(_user, [_setLog()]);

      await database.deleteWorkoutLog(_user, _workoutId);

      expect(
        await database.getWorkoutLogs(_user, DateTime.utc(2026, 7, 13)),
        isEmpty,
      );
      expect(await database.getWorkoutSetLogs(_user, _workoutId), isEmpty);
      final byDomain = {
        for (final mutation in await database.getTrainingSyncOutbox(_user))
          mutation.domain: mutation,
      };
      expect(
        byDomain[TrainingSyncDomain.workout]?.operation,
        TrainingSyncOperation.delete,
      );
      expect(
        byDomain[TrainingSyncDomain.setLog]?.operation,
        TrainingSyncOperation.delete,
      );
    },
  );

  test('adding the same workout id is an idempotent sync upsert', () async {
    await database.addWorkoutLog(_user, _workout(reps: 8));
    await database.addWorkoutLog(_user, _workout(reps: 10));

    final stored = await database.getWorkoutLogs(
      _user,
      DateTime.utc(2026, 7, 13),
    );
    expect(stored, hasLength(1));
    expect(stored.single.reps, 10);
    final mutations = (await database.getTrainingSyncOutbox(_user))
        .where((mutation) => mutation.domain == TrainingSyncDomain.workout)
        .toList();
    expect(mutations, hasLength(1));
    expect(mutations.single.entityId, _workoutId);
    expect(mutations.single.decodeWorkout().reps, 10);
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:workout'),
      isNull,
    );
  });

  test('same-id workout without child sets can move to another slot', () async {
    await database.addWorkoutLog(_user, _workout());

    await database.addWorkoutLog(
      _user,
      _workout(
        exerciseId: 'exercise-2',
        programId: 'program-2',
        programDayId: 'day-2',
        programExerciseId: 'slot-2',
      ),
    );

    final stored = await database.getWorkoutLogs(
      _user,
      DateTime.utc(2026, 7, 13),
    );
    expect(stored, hasLength(1));
    expect(stored.single.exerciseId, 'exercise-2');
    expect(stored.single.programId, 'program-2');
    expect(stored.single.programDayId, 'day-2');
    expect(stored.single.programExerciseId, 'slot-2');
    final workoutMutations = (await database.getTrainingSyncOutbox(
      _user,
    )).where((mutation) => mutation.domain == TrainingSyncDomain.workout);
    expect(workoutMutations, hasLength(1));
    expect(workoutMutations.single.decodeWorkout().exerciseId, 'exercise-2');
  });

  test(
    'same-id workout with child sets can update metrics in the same slot',
    () async {
      await database.addWorkoutLog(_user, _workout(reps: 8));
      await database.saveWorkoutSetLogs(_user, [_setLog()]);

      await database.addWorkoutLog(_user, _workout(reps: 10));

      final stored = await database.getWorkoutLogs(
        _user,
        DateTime.utc(2026, 7, 13),
      );
      expect(stored, hasLength(1));
      expect(stored.single.reps, 10);
      expect(await database.getWorkoutSetLogs(_user, _workoutId), hasLength(1));
      final mutations = await database.getTrainingSyncOutbox(_user);
      final workoutMutation = mutations.singleWhere(
        (mutation) => mutation.domain == TrainingSyncDomain.workout,
      );
      expect(workoutMutation.decodeWorkout().reps, 10);
      expect(
        mutations.where(
          (mutation) => mutation.domain == TrainingSyncDomain.workout,
        ),
        hasLength(1),
      );
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:workout'),
        isNull,
      );
    },
  );

  test(
    'same-id workout with child sets rejects identity changes atomically',
    () async {
      final metadataWrites = <String>[];
      database = AppDatabase.forTesting(
        trainingSyncEnabled: true,
        beforeTrainingSyncMetadataWrite: (key) async {
          metadataWrites.add(key);
        },
      );
      await database.addWorkoutLog(_user, _workout());
      await database.saveWorkoutSetLogs(_user, [_setLog()]);
      metadataWrites.clear();

      const protectedKeys = [
        '$_user:workout_logs',
        '$_user:workout_set_logs',
        '$_user:training_sync_outbox',
        '$_user:training_sync_recovery_v1:workout',
        '$_user:training_sync_recovery_v1:set',
        '$_user:training_sync_bootstrap_v1',
      ];
      final before = <String, String?>{};
      for (final key in protectedKeys) {
        before[key] = await _storage.read(key: key);
      }

      final invalidUpdates = [
        _workout(exerciseId: 'exercise-2'),
        _workout(programId: 'program-2'),
        _workout(programDayId: 'day-2'),
        _workout(programExerciseId: 'slot-2'),
      ];
      for (final update in invalidUpdates) {
        await expectLater(
          database.addWorkoutLog(_user, update),
          throwsA(isA<StateError>()),
        );
        final after = <String, String?>{};
        for (final key in protectedKeys) {
          after[key] = await _storage.read(key: key);
        }
        expect(after, before);
      }

      expect(metadataWrites, isEmpty);
      final stored = (await database.getWorkoutLogs(
        _user,
        DateTime.utc(2026, 7, 13),
      )).single;
      expect(stored.exerciseId, 'exercise-1');
      expect(stored.programId, 'program-1');
      expect(stored.programDayId, 'day-1');
      expect(stored.programExerciseId, 'slot-1');
    },
  );

  test(
    'set with a non-UUID parent stays local without blocking set sync',
    () async {
      final workout = _workout(id: 'legacy-workout-id');
      final setLog = _setLog(workoutId: workout.id);
      await database.addWorkoutLog(_user, workout);
      await database.saveWorkoutSetLogs(_user, [setLog]);

      final storedSet = (await database.getWorkoutSetLogs(
        _user,
        workout.id,
      )).single;
      expect(storedSet.id, setLog.id);
      expect(storedSet.workoutLogId, workout.id);
      expect(
        (await database.getTrainingSyncOutbox(
          _user,
        )).map((item) => item.domain),
        isEmpty,
      );
    },
  );

  test(
    'enabled syncable set becoming local-only creates a tombstone',
    () async {
      await database.addWorkoutLog(_user, _workout());
      await database.saveWorkoutSetLogs(_user, [_setLog()]);

      await database.saveWorkoutSetLogs(_user, [_setLog(programDayId: null)]);

      final stored = (await database.getWorkoutSetLogs(
        _user,
        _workoutId,
      )).single;
      expect(stored.programDayId, isNull);
      final mutation = (await database.getTrainingSyncOutbox(
        _user,
      )).singleWhere((item) => item.domain == TrainingSyncDomain.setLog);
      expect(mutation.operation, TrainingSyncOperation.delete);
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNull,
      );
    },
  );

  test(
    'rollback syncable set becoming local-only rebuilds a tombstone',
    () async {
      await database.addWorkoutLog(_user, _workout());
      await database.saveWorkoutSetLogs(_user, [_setLog()]);
      await database.bootstrapTrainingSyncOutbox(_user);
      await _ackAll(database);

      final disabled = AppDatabase.forTesting(trainingSyncEnabled: false);
      await disabled.saveWorkoutSetLogs(_user, [_setLog(programDayId: null)]);
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNotNull,
      );
      expect(await disabled.getTrainingSyncOutbox(_user), isEmpty);

      final reenabled = AppDatabase.forTesting(trainingSyncEnabled: true);
      await reenabled.bootstrapTrainingSyncOutbox(_user);

      final mutation = (await reenabled.getTrainingSyncOutbox(_user)).single;
      expect(mutation.domain, TrainingSyncDomain.setLog);
      expect(mutation.entityId, 'set-1');
      expect(mutation.operation, TrainingSyncOperation.delete);
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNull,
      );
    },
  );

  test(
    'bootstrapped disabled never-syncable set writes no sync metadata',
    () async {
      final metadataWrites = <String>[];
      final legacyWorkout = _workout(id: 'legacy-workout-id');
      FlutterSecureStorage.setMockInitialValues({
        '$_user:training_sync_bootstrap_v1': 'true',
        '$_user:workout_logs': _v1([legacyWorkout.toJson()]),
      });
      final disabled = AppDatabase.forTesting(
        trainingSyncEnabled: false,
        beforeTrainingSyncMetadataWrite: (key) async {
          metadataWrites.add(key);
        },
      );

      await disabled.saveWorkoutSetLogs(_user, [
        _setLog(workoutId: legacyWorkout.id, programDayId: null),
      ]);

      expect(
        await disabled.getWorkoutSetLogs(_user, legacyWorkout.id),
        hasLength(1),
      );
      expect(metadataWrites, isEmpty);
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNull,
      );
      expect(await _storage.read(key: '$_user:training_sync_outbox'), isNull);
    },
  );

  test(
    'first enabled bootstrap captures existing snapshots exactly once',
    () async {
      final program = _program();
      final rule = _rule();
      final workout = _workout();
      final setLog = _setLog();
      FlutterSecureStorage.setMockInitialValues({
        '$_user:training_programs': _v1([program.toJson()]),
        '$_user:progression_rules': _v1([rule.toJson()]),
        '$_user:workout_logs': _v1([workout.toJson()]),
        '$_user:workout_set_logs': _v1([setLog.toJson()]),
      });

      await database.bootstrapTrainingSyncOutbox(_user);
      final first = await database.getTrainingSyncOutbox(_user);
      expect(
        first.map((item) => item.domain).toSet(),
        TrainingSyncDomain.values.toSet(),
      );

      final programMutation = first.singleWhere(
        (item) => item.domain == TrainingSyncDomain.program,
      );
      await database.acknowledgeTrainingSyncMutation(
        _user,
        domain: programMutation.domain,
        entityId: programMutation.entityId,
        token: programMutation.token,
      );
      await database.bootstrapTrainingSyncOutbox(_user);
      expect(
        (await database.getTrainingSyncOutbox(
          _user,
        )).map((item) => item.domain),
        isNot(contains(TrainingSyncDomain.program)),
      );
    },
  );

  test('remote snapshot replace does not create outbox entries', () async {
    final workout = _workout();
    expect(
      await database.replaceTrainingProgramsFromSyncIfNoPending(_user, [
        _program(),
      ]),
      isTrue,
    );
    expect(
      await database.replaceProgressionRulesFromSyncIfNoPending(_user, [
        _rule(),
      ]),
      isTrue,
    );
    expect(
      await database.replaceWorkoutLogsFromSyncIfNoPending(_user, [workout]),
      isTrue,
    );
    expect(
      await database.replaceWorkoutSetLogsFromSyncIfNoPending(_user, [
        _setLog(),
      ]),
      isTrue,
    );

    expect(await database.getTrainingSyncOutbox(_user), isEmpty);
    final restored = (await database.getWorkoutLogs(
      _user,
      DateTime.utc(2026, 7, 13),
    )).single;
    expect(restored.programId, 'program-1');
    expect(restored.programDayId, 'day-1');
    expect(restored.programExerciseId, 'slot-1');
  });

  test('disabled capability never reads or grows a training outbox', () async {
    const sentinel = '{not-json-from-a-future-version';
    FlutterSecureStorage.setMockInitialValues({
      '$_user:training_sync_outbox': sentinel,
    });
    final disabled = AppDatabase.forTesting(trainingSyncEnabled: false);

    await disabled.saveTrainingProgram(_user, _program());
    await disabled.saveProgressionRule(_user, _rule());
    await disabled.addWorkoutLog(_user, _workout());
    await disabled.saveWorkoutSetLogs(_user, [_setLog()]);

    expect(await disabled.getTrainingSyncOutbox(_user), isEmpty);
    expect(await _storage.read(key: '$_user:training_sync_outbox'), sentinel);
    expect(
      await _storage.read(key: '$_user:training_sync_bootstrap_v1'),
      isNull,
    );
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:program'),
      isNull,
    );
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:workout'),
      isNull,
    );
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:rule'),
      isNull,
    );
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
      isNull,
    );
  });

  test(
    'rollback-disabled writes rebuild upserts and tombstones after re-enable',
    () async {
      await database.saveTrainingProgram(
        _user,
        _program(id: 'program-1', name: 'Existing'),
      );
      await database.bootstrapTrainingSyncOutbox(_user);
      await _ackAll(database);
      final emptyOutboxRaw = await _storage.read(
        key: '$_user:training_sync_outbox',
      );

      final disabled = AppDatabase.forTesting(trainingSyncEnabled: false);
      await Future.wait([
        disabled.deleteTrainingProgram(_user, 'program-1'),
        disabled.saveTrainingProgram(
          _user,
          _program(id: 'program-2', name: 'Added while disabled'),
        ),
      ]);

      expect(
        await _storage.read(key: '$_user:training_sync_outbox'),
        emptyOutboxRaw,
      );
      final recoveryRaw = await _storage.read(
        key: '$_user:training_sync_recovery_v1:program',
      );
      final recovery = jsonDecode(recoveryRaw!) as Map<String, dynamic>;
      expect(recovery['entityIds'], ['program-1', 'program-2']);

      final reenabled = AppDatabase.forTesting(trainingSyncEnabled: true);
      expect(
        await reenabled.replaceTrainingProgramsFromSyncIfNoPending(_user, [
          _program(id: 'program-1', name: 'Remote stale'),
        ]),
        isFalse,
      );
      await reenabled.bootstrapTrainingSyncOutbox(_user);

      final mutations = await reenabled.getTrainingSyncOutbox(_user);
      expect(mutations, hasLength(2));
      expect(
        mutations.singleWhere((item) => item.entityId == 'program-1').operation,
        TrainingSyncOperation.delete,
      );
      final upsert = mutations.singleWhere(
        (item) => item.entityId == 'program-2',
      );
      expect(upsert.operation, TrainingSyncOperation.upsert);
      expect(upsert.decodeProgram().name, 'Added while disabled');
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:program'),
        isNull,
      );
      expect(
        await reenabled.replaceTrainingProgramsFromSyncIfNoPending(_user, [
          _program(id: 'program-1', name: 'Remote stale'),
        ]),
        isFalse,
      );
    },
  );

  test(
    'outbox failure keeps program recovery pending and bootstrap repairs it',
    () async {
      var failNextOutboxWrite = false;
      database = AppDatabase.forTesting(
        trainingSyncEnabled: true,
        beforeTrainingSyncMetadataWrite: (key) async {
          if (failNextOutboxWrite && key == '$_user:training_sync_outbox') {
            failNextOutboxWrite = false;
            throw StateError('injected outbox failure');
          }
        },
      );
      await database.saveTrainingProgram(
        _user,
        _program(name: 'Before failure'),
      );
      await database.bootstrapTrainingSyncOutbox(_user);
      await _ackAll(database);

      failNextOutboxWrite = true;
      await expectLater(
        database.saveTrainingProgram(_user, _program(name: 'Recovered local')),
        throwsA(isA<StateError>()),
      );

      expect(
        (await database.getTrainingPrograms(_user)).single.name,
        'Recovered local',
      );
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:program'),
        isNotNull,
      );
      expect(
        await database.replaceTrainingProgramsFromSyncIfNoPending(_user, [
          _program(name: 'Remote stale'),
        ]),
        isFalse,
      );

      await database.bootstrapTrainingSyncOutbox(_user);
      final repaired = (await database.getTrainingSyncOutbox(_user)).single;
      expect(repaired.domain, TrainingSyncDomain.program);
      expect(repaired.operation, TrainingSyncOperation.upsert);
      expect(repaired.decodeProgram().name, 'Recovered local');
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:program'),
        isNull,
      );
      expect(
        await database.replaceTrainingProgramsFromSyncIfNoPending(_user, [
          _program(name: 'Remote stale'),
        ]),
        isFalse,
      );
    },
  );

  test(
    'outbox failure after set write is recovered from the stored set',
    () async {
      var failNextOutboxWrite = false;
      database = AppDatabase.forTesting(
        trainingSyncEnabled: true,
        beforeTrainingSyncMetadataWrite: (key) async {
          if (failNextOutboxWrite && key == '$_user:training_sync_outbox') {
            failNextOutboxWrite = false;
            throw StateError('injected outbox failure');
          }
        },
      );
      await database.addWorkoutLog(_user, _workout());
      await database.bootstrapTrainingSyncOutbox(_user);
      await _ackAll(database);

      failNextOutboxWrite = true;
      await expectLater(
        database.saveWorkoutSetLogs(_user, [_setLog()]),
        throwsA(isA<StateError>()),
      );

      expect(await database.getWorkoutSetLogs(_user, _workoutId), hasLength(1));
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNotNull,
      );
      expect(
        await database.replaceWorkoutSetLogsFromSyncIfNoPending(
          _user,
          const [],
        ),
        isFalse,
      );

      await database.bootstrapTrainingSyncOutbox(_user);
      final repaired = (await database.getTrainingSyncOutbox(_user)).single;
      expect(repaired.domain, TrainingSyncDomain.setLog);
      expect(repaired.operation, TrainingSyncOperation.upsert);
      expect(repaired.decodeSetLog().id, 'set-1');
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        isNull,
      );
    },
  );

  test('outbox failure after set delete is recovered as a tombstone', () async {
    var failNextOutboxWrite = false;
    database = AppDatabase.forTesting(
      trainingSyncEnabled: true,
      beforeTrainingSyncMetadataWrite: (key) async {
        if (failNextOutboxWrite && key == '$_user:training_sync_outbox') {
          failNextOutboxWrite = false;
          throw StateError('injected outbox failure');
        }
      },
    );
    await database.addWorkoutLog(_user, _workout());
    await database.saveWorkoutSetLogs(_user, [_setLog()]);
    await database.bootstrapTrainingSyncOutbox(_user);
    await _ackAll(database);

    failNextOutboxWrite = true;
    await expectLater(
      database.deleteWorkoutSetLog(_user, 'set-1'),
      throwsA(isA<StateError>()),
    );

    expect(await database.getWorkoutSetLogs(_user, _workoutId), isEmpty);
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
      isNotNull,
    );
    await database.bootstrapTrainingSyncOutbox(_user);

    final repaired = (await database.getTrainingSyncOutbox(_user)).single;
    expect(repaired.domain, TrainingSyncDomain.setLog);
    expect(repaired.entityId, 'set-1');
    expect(repaired.operation, TrainingSyncOperation.delete);
    expect(
      await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
      isNull,
    );
  });

  test('corrupt recovery owner domain and version fail closed', () async {
    final invalidEnvelopes = <Map<String, dynamic>>[
      {
        'schemaVersion': 1,
        'userId': 'different-owner',
        'domain': 'set',
        'entityIds': ['set-1'],
      },
      {
        'schemaVersion': 1,
        'userId': _user,
        'domain': 'workout',
        'entityIds': ['set-1'],
      },
      {
        'schemaVersion': 99,
        'userId': _user,
        'domain': 'set',
        'entityIds': ['set-1'],
      },
    ];

    for (final envelope in invalidEnvelopes) {
      final raw = jsonEncode(envelope);
      FlutterSecureStorage.setMockInitialValues({
        '$_user:training_sync_recovery_v1:set': raw,
      });
      final guarded = AppDatabase.forTesting(trainingSyncEnabled: true);

      await expectLater(
        guarded.bootstrapTrainingSyncOutbox(_user),
        throwsA(isA<CorruptStorageDataException>()),
      );
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:set'),
        raw,
      );
      expect(await _storage.read(key: '$_user:training_sync_outbox'), isNull);
      expect(
        await _storage.read(key: '$_user:training_sync_bootstrap_v1'),
        isNull,
      );
    }
  });

  test(
    'concurrent workout cascade and set save cannot leave an orphan',
    () async {
      await database.addWorkoutLog(_user, _workout());
      await database.saveWorkoutSetLogs(_user, [_setLog()]);

      final deletion = database.deleteWorkoutLog(_user, _workoutId);
      final lateSave = database.saveWorkoutSetLogs(_user, [
        _setLog(id: 'late-set'),
      ]);
      await deletion;
      await expectLater(lateSave, throwsA(isA<StateError>()));

      expect(await database.getAllWorkoutLogsForSync(_user), isEmpty);
      expect(await database.getWorkoutSetLogs(_user, _workoutId), isEmpty);
    },
  );

  test(
    'concurrent workout cascade and remote set replace cannot orphan a set',
    () async {
      await database.addWorkoutLog(_user, _workout());
      await _ackAll(database);

      final deletion = database.deleteWorkoutLog(_user, _workoutId);
      final lateReplace = database.replaceWorkoutSetLogsFromSyncIfNoPending(
        _user,
        [_setLog(id: 'remote-late-set')],
      );
      await deletion;
      await expectLater(lateReplace, throwsA(isA<StateError>()));

      expect(await database.getAllWorkoutLogsForSync(_user), isEmpty);
      expect(await database.getWorkoutSetLogs(_user, _workoutId), isEmpty);
    },
  );

  test(
    'bootstrap recovery and a concurrent domain write do not lose ids',
    () async {
      final bootstrapOutboxWritten = Completer<void>();
      final allowRecoveryClear = Completer<void>();
      var failNextOutboxWrite = false;
      var blockBootstrapRecoveryClear = false;
      var bootstrapWroteOutbox = false;
      database = AppDatabase.forTesting(
        trainingSyncEnabled: true,
        beforeTrainingSyncMetadataWrite: (key) async {
          if (key == '$_user:training_sync_outbox') {
            if (failNextOutboxWrite) {
              failNextOutboxWrite = false;
              throw StateError('injected outbox failure');
            }
            if (blockBootstrapRecoveryClear) {
              bootstrapWroteOutbox = true;
              if (!bootstrapOutboxWritten.isCompleted) {
                bootstrapOutboxWritten.complete();
              }
            }
          }
          if (key == '$_user:training_sync_recovery_v1:program' &&
              blockBootstrapRecoveryClear &&
              bootstrapWroteOutbox) {
            await allowRecoveryClear.future;
          }
        },
      );
      await database.bootstrapTrainingSyncOutbox(_user);

      failNextOutboxWrite = true;
      await expectLater(
        database.saveTrainingProgram(
          _user,
          _program(id: 'program-1', name: 'Recovered first'),
        ),
        throwsA(isA<StateError>()),
      );

      blockBootstrapRecoveryClear = true;
      final bootstrap = database.bootstrapTrainingSyncOutbox(_user);
      await bootstrapOutboxWritten.future;
      final concurrentWrite = database.saveTrainingProgram(
        _user,
        _program(id: 'program-2', name: 'Written concurrently'),
      );
      allowRecoveryClear.complete();
      await Future.wait([bootstrap, concurrentWrite]);

      final mutations = await database.getTrainingSyncOutbox(_user);
      expect(mutations.map((mutation) => mutation.entityId).toSet(), {
        'program-1',
        'program-2',
      });
      expect(
        await _storage.read(key: '$_user:training_sync_recovery_v1:program'),
        isNull,
      );
    },
  );

  test('pending domain makes conditional replacement a no-op', () async {
    await database.saveTrainingProgram(_user, _program(name: 'Local'));

    final replaced = await database.replaceTrainingProgramsFromSyncIfNoPending(
      _user,
      [_program(name: 'Remote stale')],
    );

    expect(replaced, isFalse);
    expect((await database.getTrainingPrograms(_user)).single.name, 'Local');
  });

  test(
    'remote replacement preserves legacy local-only workout and set',
    () async {
      final legacyWorkout = _workout(id: 'legacy-workout-id');
      final legacySet = _setLog(workoutId: legacyWorkout.id);
      FlutterSecureStorage.setMockInitialValues({
        '$_user:workout_logs': _v1([legacyWorkout.toJson()]),
        '$_user:workout_set_logs': _v1([legacySet.toJson()]),
      });

      expect(
        await database.replaceWorkoutLogsFromSyncIfNoPending(_user, [
          _workout(),
        ]),
        isTrue,
      );
      expect(
        await database.replaceWorkoutSetLogsFromSyncIfNoPending(_user, [
          _setLog(),
        ]),
        isTrue,
      );

      expect(await database.getAllWorkoutLogsForSync(_user), hasLength(2));
      final restoredLegacySets = await database.getWorkoutSetLogs(
        _user,
        legacyWorkout.id,
      );
      expect(restoredLegacySets, hasLength(1));
      expect(restoredLegacySets.single.id, legacySet.id);
    },
  );
}

Future<void> _ackAll(AppDatabase database) async {
  final mutations = await database.getTrainingSyncOutbox(_user);
  for (final mutation in mutations) {
    await database.acknowledgeTrainingSyncMutation(
      _user,
      domain: mutation.domain,
      entityId: mutation.entityId,
      token: mutation.token,
    );
  }
}

String _v1(List<Map<String, dynamic>> data) =>
    jsonEncode({'schemaVersion': 1, 'data': data});

TrainingProgram _program({
  String userId = _user,
  String id = 'program-1',
  String name = 'Program',
}) {
  final now = DateTime.utc(2026, 7, 13);
  return TrainingProgram(
    id: id,
    userId: userId,
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

ProgressionRule _rule() => const ProgressionRule(
  id: 'rule-1',
  userId: _user,
  exerciseId: 'exercise-1',
  type: ProgressionType.fixedWeight,
);

WorkoutLog _workout({
  String id = _workoutId,
  int reps = 8,
  String exerciseId = 'exercise-1',
  String? programId = 'program-1',
  String? programDayId = 'day-1',
  String? programExerciseId = 'slot-1',
}) => WorkoutLog(
  id: id,
  userId: _user,
  exerciseId: exerciseId,
  programId: programId,
  programDayId: programDayId,
  programExerciseId: programExerciseId,
  date: DateTime.utc(2026, 7, 13),
  sets: 3,
  reps: reps,
  weightKg: 100,
);

WorkoutSetLog _setLog({
  String id = 'set-1',
  String workoutId = _workoutId,
  String? programDayId = 'day-1',
}) => WorkoutSetLog(
  id: id,
  workoutLogId: workoutId,
  programId: 'program-1',
  programDayId: programDayId,
  programExerciseId: 'slot-1',
  setIndex: 0,
  reps: 8,
  weightKg: 100,
  completed: true,
);
