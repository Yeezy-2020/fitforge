import 'dart:async';

import 'package:fitforge/core/services/sync_service.dart';
import 'package:fitforge/core/services/training_sync.dart';
import 'package:fitforge/data/models/diet_log.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _userA = 'user-a';
const _workoutId = '550e8400-e29b-41d4-a716-446655440000';

void main() {
  group('training sync', () {
    test('pushes upserts in dependency order and deletes in reverse', () async {
      final local = _FakeLocal()..outbox[_userA] = _allMutations(_userA);
      final remote = _FakeRemote(_userA);
      final service = SyncService.forTesting(remote: remote, local: local);

      final result = await service.pushPending();

      expect(result.succeeded, isTrue);
      expect(result.trainingMutationsPushed, 8);
      expect(remote.events.where((event) => event.startsWith('training:')), [
        'training:upsert:program:program-upsert',
        'training:delete:rule:rule-delete',
        'training:upsert:rule:rule-upsert',
        'training:upsert:workout:$_workoutId',
        'training:upsert:set:set-upsert',
        'training:delete:set:set-delete',
        'training:delete:workout:550e8400-e29b-41d4-a716-446655440001',
        'training:delete:program:program-delete',
      ]);
      expect(local.outbox[_userA], isEmpty);
      expect(remote.deleteExpectedUserIds, everyElement(_userA));
      expect(remote.writeExpectedUserIds, everyElement(_userA));
    });

    test(
      'failed mutation remains queued and its domain is not pulled',
      () async {
        final mutation = _programMutation(_userA, token: 'failed');
        final local = _FakeLocal()..outbox[_userA] = [mutation];
        final remote = _FakeRemote(_userA)
          ..failEvents.add('training:upsert:program:program-upsert');
        final service = SyncService.forTesting(remote: remote, local: local);

        final result = await service.fullSync();

        expect(result.succeeded, isFalse);
        expect(local.outbox[_userA], [same(mutation)]);
        expect(remote.events, contains('training:pull:program'));
        expect(
          local.replacedDomains,
          isNot(contains(TrainingSyncDomain.program)),
        );
        expect(
          result.issues
              .singleWhere((issue) => issue.phase == 'training-push')
              .domain,
          TrainingSyncDomain.program,
        );
        expect(
          result.trainingDomainsPulled,
          containsAll(<TrainingSyncDomain>{
            TrainingSyncDomain.rule,
            TrainingSyncDomain.workout,
            TrainingSyncDomain.setLog,
          }),
        );
      },
    );

    test('tokenized ack does not clear a newer mutation', () async {
      final original = _programMutation(_userA, token: 'old');
      final newer = _programMutation(
        _userA,
        token: 'new',
        name: 'Newer local edit',
      );
      final local = _FakeLocal()..outbox[_userA] = [original];
      final remote = _FakeRemote(_userA)
        ..afterEvent = (event) {
          if (event == 'training:upsert:program:program-upsert') {
            local.outbox[_userA] = [newer];
          }
        };
      final service = SyncService.forTesting(remote: remote, local: local);

      final result = await service.pushPending();

      expect(result.trainingMutationsPushed, 1);
      expect(local.outbox[_userA], [same(newer)]);
    });

    test(
      'account change aborts before old account ack or later calls',
      () async {
        final mutation = _programMutation(_userA, token: 'old-user');
        final local = _FakeLocal()..outbox[_userA] = [mutation];
        late final _FakeRemote remote;
        remote = _FakeRemote(_userA)
          ..afterEvent = (event) {
            if (event == 'training:upsert:program:program-upsert') {
              remote.userIdValue = 'user-b';
            }
          };
        final service = SyncService.forTesting(remote: remote, local: local);

        final result = await service.fullSync();

        expect(result.accountChanged, isTrue);
        expect(result.issues.last.error, isA<SyncAccountChangedException>());
        expect(local.outbox[_userA], [same(mutation)]);
        expect(remote.events, ['training:upsert:program:program-upsert']);
        expect(local.acknowledged, isEmpty);
      },
    );

    test('delete tombstone propagates and is acknowledged', () async {
      final mutation = _deleteMutation(
        _userA,
        TrainingSyncDomain.program,
        'program-delete',
        'delete-token',
      );
      final local = _FakeLocal()..outbox[_userA] = [mutation];
      final remote = _FakeRemote(_userA);

      final result = await SyncService.forTesting(
        remote: remote,
        local: local,
      ).pushPending();

      expect(result.succeeded, isTrue);
      expect(remote.events, contains('training:delete:program:program-delete'));
      expect(local.outbox[_userA], isEmpty);
    });

    test(
      'fresh device restores exact server snapshots including slot ids',
      () async {
        final workout = _workout(_userA, _workoutId);
        final remote = _FakeRemote(_userA)
          ..programs = [_program(_userA, 'program-upsert')]
          ..rules = [_rule(_userA, 'rule-upsert')]
          ..workouts = [workout]
          ..setLogs = [_setLog('set-upsert', _workoutId)];
        final local = _FakeLocal();

        final result = await SyncService.forTesting(
          remote: remote,
          local: local,
        ).fullSync();

        expect(result.succeeded, isTrue);
        expect(result.trainingDomainsPulled, TrainingSyncDomain.values.toSet());
        expect(local.programs.single.id, 'program-upsert');
        expect(local.rules.single.id, 'rule-upsert');
        expect(local.workouts.single.programId, 'program-upsert');
        expect(local.workouts.single.programDayId, 'day-1');
        expect(local.workouts.single.programExerciseId, 'slot-1');
        expect(local.setLogs.single.programDayId, 'day-1');
        expect(remote.events, isNot(contains('legacy:pull:workout')));
      },
    );

    test(
      'failed workout tombstone is not revived by the legacy pull path',
      () async {
        final tombstone = _deleteMutation(
          _userA,
          TrainingSyncDomain.workout,
          _workoutId,
          'delete-workout',
        );
        final local = _FakeLocal()..outbox[_userA] = [tombstone];
        final remote = _FakeRemote(_userA)
          ..legacyWorkouts = [_workout(_userA, _workoutId)]
          ..workouts = [_workout(_userA, _workoutId)]
          ..failEvents.add('training:delete:workout:$_workoutId');

        final result = await SyncService.forTesting(
          remote: remote,
          local: local,
        ).fullSync();

        expect(result.succeeded, isFalse);
        expect(remote.events, isNot(contains('legacy:pull:workout')));
        expect(local.workouts, isEmpty);
        expect(local.outbox[_userA], [same(tombstone)]);
      },
    );

    test(
      'disabled capability performs legacy sync without training APIs',
      () async {
        final local = _FakeLocal()
          ..unsyncedWorkouts[_userA] = [_workout(_userA, _workoutId)];
        final remote = _FakeRemote(_userA);

        final result = await SyncService.forTesting(
          remote: remote,
          local: local,
          trainingSyncEnabled: false,
        ).fullSync();

        expect(result.succeeded, isTrue);
        expect(remote.events, contains('legacy:upsert:workout:$_workoutId'));
        expect(
          remote.events.where((event) => event.startsWith('training:')),
          isEmpty,
        );
        expect(local.trainingApiCalls, 0);
      },
    );

    test(
      'non-UUID workout is typed, quarantined, and does not block',
      () async {
        final mutation = _workoutMutation(
          _userA,
          id: 'legacy-local-id',
          token: 'legacy-token',
        );
        final local = _FakeLocal()..outbox[_userA] = [mutation];
        final remote = _FakeRemote(_userA);

        final result = await SyncService.forTesting(
          remote: remote,
          local: local,
        ).pushPending();

        final issue = result.issues.singleWhere(
          (candidate) => candidate.phase == 'training-quarantine',
        );
        expect(issue.error, isA<UnsyncableTrainingMutationException>());
        expect(local.outbox[_userA], isEmpty);
        expect(
          remote.events.where((event) => event.startsWith('training:')),
          isEmpty,
        );
      },
    );

    test('concurrent runs are serialized before reading the outbox', () async {
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var shouldBlock = true;
      final original = _programMutation(_userA, token: 'old');
      final newer = _programMutation(
        _userA,
        token: 'new',
        name: 'Newer local edit',
      );
      final local = _FakeLocal()..outbox[_userA] = [original];
      final remote = _FakeRemote(_userA)
        ..beforeEvent = (event) async {
          if (event == 'training:upsert:program:program-upsert' &&
              shouldBlock) {
            shouldBlock = false;
            firstStarted.complete();
            await releaseFirst.future;
          }
        };
      final service = SyncService.forTesting(remote: remote, local: local);

      final first = service.pushPending();
      await firstStarted.future;
      local.outbox[_userA] = [newer];
      final second = service.pushPending();
      await Future<void>.delayed(Duration.zero);

      expect(
        remote.events
            .where((event) => event == 'training:upsert:program:program-upsert')
            .length,
        1,
      );
      releaseFirst.complete();
      await Future.wait([first, second]);

      expect(remote.maxConcurrentCalls, 1);
      expect(local.outbox[_userA], isEmpty);
      expect(
        remote.events
            .where((event) => event == 'training:upsert:program:program-upsert')
            .length,
        2,
      );
    });

    test('pending mutation created during pull prevents replacement', () async {
      final local = _FakeLocal();
      final pending = _programMutation(_userA, token: 'during-pull');
      final remote = _FakeRemote(_userA)
        ..programs = [_program(_userA, 'program-upsert')]
        ..afterEvent = (event) {
          if (event == 'training:pull:program') {
            local.outbox[_userA] = [pending];
          }
        };

      final result = await SyncService.forTesting(
        remote: remote,
        local: local,
      ).pullLatest();

      expect(
        result.trainingDomainsPulled,
        isNot(contains(TrainingSyncDomain.program)),
      );
      expect(local.programs, isEmpty);
      expect(local.outbox[_userA], [same(pending)]);
    });

    test(
      'unexpected local read failure is returned instead of escaping',
      () async {
        final local = _FakeLocal()..throwOnOutboxRead = true;
        final result = await SyncService.forTesting(
          remote: _FakeRemote(_userA),
          local: local,
        ).fullSync();

        expect(result.succeeded, isFalse);
        expect(result.issues, hasLength(1));
        expect(result.issues.single.phase, 'full-sync-unhandled');
        expect(result.issues.single.error, isA<StateError>());
      },
    );
  });
}

class _FakeRemote implements SyncRemoteGateway {
  String? userIdValue;
  final List<String> events = [];
  final Set<String> failEvents = {};
  final List<String> deleteExpectedUserIds = [];
  final List<String> writeExpectedUserIds = [];
  void Function(String event)? afterEvent;
  Future<void> Function(String event)? beforeEvent;
  int _activeCalls = 0;
  int maxConcurrentCalls = 0;
  List<TrainingProgram> programs = [];
  List<ProgressionRule> rules = [];
  List<WorkoutLog> workouts = [];
  List<WorkoutLog> legacyWorkouts = [];
  List<WorkoutSetLog> setLogs = [];

  _FakeRemote(this.userIdValue);

  @override
  String? get userId => userIdValue;

  Future<void> _write(String event) async {
    events.add(event);
    _activeCalls++;
    if (_activeCalls > maxConcurrentCalls) {
      maxConcurrentCalls = _activeCalls;
    }
    try {
      await beforeEvent?.call(event);
      afterEvent?.call(event);
      if (failEvents.contains(event)) throw StateError('failed: $event');
    } finally {
      _activeCalls--;
    }
  }

  Future<List<T>> _read<T>(String event, List<T> values) async {
    await _write(event);
    return List<T>.of(values);
  }

  @override
  Future<void> addDietLog(DietLog log, {required String expectedUserId}) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('legacy:upsert:diet:${log.id}');
  }

  @override
  Future<void> addWorkoutLog(WorkoutLog log, {required String expectedUserId}) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('legacy:upsert:workout:${log.id}');
  }

  @override
  Future<void> deleteDietLog(String logId, {required String expectedUserId}) {
    deleteExpectedUserIds.add(expectedUserId);
    return _write('legacy:delete:diet:$logId');
  }

  @override
  Future<void> deleteProgressionRule(
    String ruleId, {
    required String expectedUserId,
  }) {
    deleteExpectedUserIds.add(expectedUserId);
    return _write('training:delete:rule:$ruleId');
  }

  @override
  Future<void> deleteTrainingProgram(
    String programId, {
    required String expectedUserId,
  }) {
    deleteExpectedUserIds.add(expectedUserId);
    return _write('training:delete:program:$programId');
  }

  @override
  Future<void> deleteWorkoutLog(
    String logId, {
    required String expectedUserId,
  }) {
    deleteExpectedUserIds.add(expectedUserId);
    return _write('training:delete:workout:$logId');
  }

  @override
  Future<void> deleteWorkoutSetLog(
    String setLogId, {
    required String expectedUserId,
  }) {
    deleteExpectedUserIds.add(expectedUserId);
    return _write('training:delete:set:$setLogId');
  }

  @override
  Future<List<DietLog>> getDietLogs(DateTime date) =>
      _read('legacy:pull:diet', const []);
  @override
  Future<List<ProgressionRule>> getAllProgressionRules() =>
      _read('training:pull:rule', rules);
  @override
  Future<List<TrainingProgram>> getAllTrainingPrograms() =>
      _read('training:pull:program', programs);
  @override
  Future<List<WorkoutLog>> getAllWorkoutLogs() =>
      _read('training:pull:workout', workouts);
  @override
  Future<List<WorkoutSetLog>> getAllWorkoutSetLogs() =>
      _read('training:pull:set', setLogs);
  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(DateTime month) =>
      _read('legacy:pull:workout', legacyWorkouts);
  @override
  Future<void> upsertProgressionRule(
    ProgressionRule rule, {
    required String expectedUserId,
  }) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('training:upsert:rule:${rule.id}');
  }

  @override
  Future<void> upsertTrainingProgram(
    TrainingProgram program, {
    required String expectedUserId,
  }) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('training:upsert:program:${program.id}');
  }

  @override
  Future<void> upsertWorkoutLog(
    WorkoutLog log, {
    required String expectedUserId,
  }) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('training:upsert:workout:${log.id}');
  }

  @override
  Future<void> upsertWorkoutSetLog(
    WorkoutSetLog log, {
    required String expectedUserId,
  }) {
    writeExpectedUserIds.add(expectedUserId);
    return _write('training:upsert:set:${log.id}');
  }
}

class _FakeLocal implements SyncLocalGateway {
  final Map<String, List<TrainingSyncMutation>> outbox = {};
  final Map<String, List<WorkoutLog>> unsyncedWorkouts = {};
  final List<String> acknowledged = [];
  final Set<TrainingSyncDomain> replacedDomains = {};
  List<TrainingProgram> programs = [];
  List<ProgressionRule> rules = [];
  List<WorkoutLog> workouts = [];
  List<WorkoutSetLog> setLogs = [];
  int trainingApiCalls = 0;
  bool throwOnOutboxRead = false;

  @override
  Future<void> acknowledgeTrainingSyncMutation(
    String userId, {
    required TrainingSyncDomain domain,
    required String entityId,
    required String token,
  }) async {
    trainingApiCalls++;
    acknowledged.add('$userId:${domain.wireName}:$entityId:$token');
    outbox[userId]?.removeWhere(
      (mutation) =>
          mutation.domain == domain &&
          mutation.entityId == entityId &&
          mutation.token == token,
    );
  }

  @override
  Future<void> bootstrapTrainingSyncOutbox(String userId) async {
    trainingApiCalls++;
    outbox.putIfAbsent(userId, () => []);
  }

  @override
  Future<List<String>> getPendingDietDeletes(String userId) async => [];
  @override
  Future<List<String>> getPendingWorkoutDeletes(String userId) async => [];
  @override
  Future<List<TrainingSyncMutation>> getTrainingSyncOutbox(
    String userId,
  ) async {
    trainingApiCalls++;
    if (throwOnOutboxRead) throw StateError('corrupt outbox');
    return List.of(outbox[userId] ?? const []);
  }

  @override
  Future<List<DietLog>> getUnsyncedDietLogs(String userId) async => [];
  @override
  Future<List<WorkoutLog>> getUnsyncedWorkoutLogs(String userId) async =>
      List.of(unsyncedWorkouts[userId] ?? const []);
  @override
  Future<void> removePendingDietDeletes(String userId, Set<String> ids) async {}
  @override
  Future<void> removePendingWorkoutDeletes(
    String userId,
    Set<String> ids,
  ) async {}
  @override
  Future<void> removeUnsyncedDietLogs(String userId, Set<String> ids) async {}
  @override
  Future<void> removeUnsyncedWorkoutLogs(String userId, Set<String> ids) async {
    unsyncedWorkouts[userId]?.removeWhere((log) => ids.contains(log.id));
  }

  @override
  Future<bool> replaceProgressionRulesFromSyncIfNoPending(
    String userId,
    List<ProgressionRule> values,
  ) async {
    trainingApiCalls++;
    if (_hasPending(userId, TrainingSyncDomain.rule)) return false;
    rules = List.of(values);
    replacedDomains.add(TrainingSyncDomain.rule);
    return true;
  }

  @override
  Future<bool> replaceTrainingProgramsFromSyncIfNoPending(
    String userId,
    List<TrainingProgram> values,
  ) async {
    trainingApiCalls++;
    if (_hasPending(userId, TrainingSyncDomain.program)) return false;
    programs = List.of(values);
    replacedDomains.add(TrainingSyncDomain.program);
    return true;
  }

  @override
  Future<bool> replaceWorkoutLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutLog> values,
  ) async {
    trainingApiCalls++;
    if (_hasPending(userId, TrainingSyncDomain.workout)) return false;
    workouts = List.of(values);
    replacedDomains.add(TrainingSyncDomain.workout);
    return true;
  }

  @override
  Future<bool> replaceWorkoutSetLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutSetLog> values,
  ) async {
    trainingApiCalls++;
    if (_hasPending(userId, TrainingSyncDomain.setLog)) return false;
    setLogs = List.of(values);
    replacedDomains.add(TrainingSyncDomain.setLog);
    return true;
  }

  bool _hasPending(String userId, TrainingSyncDomain domain) =>
      outbox[userId]?.any((mutation) => mutation.domain == domain) ?? false;

  @override
  Future<void> saveDietLogs(String userId, List<DietLog> logs) async {}
  @override
  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs) async {}
}

List<TrainingSyncMutation> _allMutations(String userId) => [
  _deleteMutation(userId, TrainingSyncDomain.program, 'program-delete', 'pd'),
  _deleteMutation(userId, TrainingSyncDomain.rule, 'rule-delete', 'rd'),
  _deleteMutation(
    userId,
    TrainingSyncDomain.workout,
    '550e8400-e29b-41d4-a716-446655440001',
    'wd',
  ),
  _deleteMutation(userId, TrainingSyncDomain.setLog, 'set-delete', 'sd'),
  _setMutation(userId, token: 'su'),
  _workoutMutation(userId, id: _workoutId, token: 'wu'),
  _ruleMutation(userId, token: 'ru'),
  _programMutation(userId, token: 'pu'),
];

TrainingSyncMutation _programMutation(
  String userId, {
  required String token,
  String name = 'Program',
}) => _mutation(
  userId,
  TrainingSyncDomain.program,
  'program-upsert',
  token,
  _program(userId, 'program-upsert', name: name).toJson(),
);

TrainingSyncMutation _ruleMutation(String userId, {required String token}) =>
    _mutation(
      userId,
      TrainingSyncDomain.rule,
      'rule-upsert',
      token,
      _rule(userId, 'rule-upsert').toJson(),
    );

TrainingSyncMutation _workoutMutation(
  String userId, {
  required String id,
  required String token,
}) => _mutation(
  userId,
  TrainingSyncDomain.workout,
  id,
  token,
  _workout(userId, id).toJson(),
);

TrainingSyncMutation _setMutation(String userId, {required String token}) =>
    _mutation(
      userId,
      TrainingSyncDomain.setLog,
      'set-upsert',
      token,
      _setLog('set-upsert', _workoutId).toJson(),
    );

TrainingSyncMutation _mutation(
  String userId,
  TrainingSyncDomain domain,
  String entityId,
  String token,
  Map<String, dynamic> payload,
) => TrainingSyncMutation.fromJson({
  'userId': userId,
  'domain': domain.wireName,
  'entityId': entityId,
  'operation': 'upsert',
  'payload': payload,
  'token': token,
}, expectedUserId: userId);

TrainingSyncMutation _deleteMutation(
  String userId,
  TrainingSyncDomain domain,
  String entityId,
  String token,
) => TrainingSyncMutation.fromJson({
  'userId': userId,
  'domain': domain.wireName,
  'entityId': entityId,
  'operation': 'delete',
  'payload': null,
  'token': token,
}, expectedUserId: userId);

TrainingProgram _program(String userId, String id, {String name = 'Program'}) {
  final now = DateTime.utc(2026, 7, 13);
  return TrainingProgram(
    id: id,
    userId: userId,
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

ProgressionRule _rule(String userId, String id) => ProgressionRule(
  id: id,
  userId: userId,
  exerciseId: 'exercise-1',
  type: ProgressionType.fixedWeight,
);

WorkoutLog _workout(String userId, String id) => WorkoutLog(
  id: id,
  userId: userId,
  exerciseId: 'exercise-1',
  programId: 'program-upsert',
  programDayId: 'day-1',
  programExerciseId: 'slot-1',
  date: DateTime.utc(2026, 7, 13),
  sets: 3,
  reps: 8,
  weightKg: 100,
);

WorkoutSetLog _setLog(String id, String workoutId) => WorkoutSetLog(
  id: id,
  workoutLogId: workoutId,
  programId: 'program-upsert',
  programDayId: 'day-1',
  programExerciseId: 'slot-1',
  setIndex: 0,
  reps: 8,
  weightKg: 100,
  completed: true,
);
