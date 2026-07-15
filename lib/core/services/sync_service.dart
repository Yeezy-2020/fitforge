import '../../data/models/diet_log.dart';
import '../../data/models/progression_rule.dart';
import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';
import '../../data/repositories/app_database.dart';
import 'supabase_service.dart';
import 'training_sync.dart';

class SyncAccountChangedException implements Exception {
  final String expectedUserId;
  final String? actualUserId;

  const SyncAccountChangedException(this.expectedUserId, this.actualUserId);

  @override
  String toString() =>
      'SyncAccountChangedException: expected $expectedUserId, '
      'found ${actualUserId ?? 'no signed-in user'}.';
}

class UnsyncableTrainingMutationException implements Exception {
  final TrainingSyncDomain domain;
  final String entityId;
  final String reason;

  const UnsyncableTrainingMutationException({
    required this.domain,
    required this.entityId,
    required this.reason,
  });

  @override
  String toString() =>
      'UnsyncableTrainingMutationException: ${domain.wireName} $entityId '
      'cannot be synced: $reason.';
}

class SyncIssue {
  final String phase;
  final Object error;
  final TrainingSyncDomain? domain;
  final String? entityId;

  const SyncIssue({
    required this.phase,
    required this.error,
    this.domain,
    this.entityId,
  });
}

class SyncRunResult {
  final String? userId;
  final int trainingMutationsPushed;
  final Set<TrainingSyncDomain> trainingDomainsPulled;
  final List<SyncIssue> issues;
  final bool accountChanged;

  const SyncRunResult({
    required this.userId,
    required this.trainingMutationsPushed,
    required this.trainingDomainsPulled,
    required this.issues,
    required this.accountChanged,
  });

  bool get succeeded => issues.isEmpty && !accountChanged;
}

abstract interface class SyncRemoteGateway {
  String? get userId;

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(DateTime month);

  Future<List<DietLog>> getDietLogs(DateTime date);

  Future<void> addWorkoutLog(WorkoutLog log, {required String expectedUserId});

  Future<void> deleteWorkoutLog(String logId, {required String expectedUserId});

  Future<void> addDietLog(DietLog log, {required String expectedUserId});

  Future<void> deleteDietLog(String logId, {required String expectedUserId});

  Future<List<TrainingProgram>> getAllTrainingPrograms();

  Future<void> upsertTrainingProgram(
    TrainingProgram program, {
    required String expectedUserId,
  });

  Future<void> deleteTrainingProgram(
    String programId, {
    required String expectedUserId,
  });

  Future<List<ProgressionRule>> getAllProgressionRules();

  Future<void> upsertProgressionRule(
    ProgressionRule rule, {
    required String expectedUserId,
  });

  Future<void> deleteProgressionRule(
    String ruleId, {
    required String expectedUserId,
  });

  Future<List<WorkoutLog>> getAllWorkoutLogs();

  Future<void> upsertWorkoutLog(
    WorkoutLog log, {
    required String expectedUserId,
  });

  Future<List<WorkoutSetLog>> getAllWorkoutSetLogs();

  Future<void> upsertWorkoutSetLog(
    WorkoutSetLog log, {
    required String expectedUserId,
  });

  Future<void> deleteWorkoutSetLog(
    String setLogId, {
    required String expectedUserId,
  });
}

abstract interface class SyncLocalGateway {
  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs);

  Future<void> saveDietLogs(String userId, List<DietLog> logs);

  Future<List<String>> getPendingWorkoutDeletes(String userId);

  Future<void> removePendingWorkoutDeletes(String userId, Set<String> ids);

  Future<List<String>> getPendingDietDeletes(String userId);

  Future<void> removePendingDietDeletes(String userId, Set<String> ids);

  Future<List<WorkoutLog>> getUnsyncedWorkoutLogs(String userId);

  Future<void> removeUnsyncedWorkoutLogs(String userId, Set<String> ids);

  Future<List<DietLog>> getUnsyncedDietLogs(String userId);

  Future<void> removeUnsyncedDietLogs(String userId, Set<String> ids);

  Future<void> bootstrapTrainingSyncOutbox(String userId);

  Future<List<TrainingSyncMutation>> getTrainingSyncOutbox(String userId);

  Future<void> acknowledgeTrainingSyncMutation(
    String userId, {
    required TrainingSyncDomain domain,
    required String entityId,
    required String token,
  });

  Future<bool> replaceTrainingProgramsFromSyncIfNoPending(
    String userId,
    List<TrainingProgram> programs,
  );

  Future<bool> replaceProgressionRulesFromSyncIfNoPending(
    String userId,
    List<ProgressionRule> rules,
  );

  Future<bool> replaceWorkoutLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutLog> logs,
  );

  Future<bool> replaceWorkoutSetLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutSetLog> logs,
  );
}

class SyncService {
  final SyncRemoteGateway _remote;
  final SyncLocalGateway _local;
  final bool trainingSyncEnabled;
  Future<void> _runTail = Future<void>.value();

  SyncService._(this._remote, this._local, {required this.trainingSyncEnabled});

  factory SyncService.forTesting({
    required SyncRemoteGateway remote,
    required SyncLocalGateway local,
    bool trainingSyncEnabled = true,
  }) => SyncService._(remote, local, trainingSyncEnabled: trainingSyncEnabled);

  static SyncService? _instance;

  static SyncService init(SupabaseService supabase, AppDatabase local) {
    _instance = SyncService._(
      _SupabaseSyncGateway(supabase),
      _AppDatabaseSyncGateway(local),
      trainingSyncEnabled: trainingSyncV1Enabled,
    );
    return _instance!;
  }

  static SyncService get instance => _instance!;

  Future<SyncRunResult> pullLatest() =>
      _runSerialized(unhandledPhase: 'pull-unhandled', action: _pullLatest);

  Future<SyncRunResult> pushPending() =>
      _runSerialized(unhandledPhase: 'push-unhandled', action: _pushPending);

  Future<SyncRunResult> fullSync() => _runSerialized(
    unhandledPhase: 'full-sync-unhandled',
    action: (userId, result) async {
      await _pushPending(userId, result);
      _requireExpectedUser(userId);
      await _pullLatest(userId, result);
    },
  );

  Future<SyncRunResult> _runSerialized({
    required String unhandledPhase,
    required Future<void> Function(String userId, _SyncAccumulator result)
    action,
  }) {
    final userId = _remote.userId;
    if (userId == null || userId.isEmpty) {
      return Future<SyncRunResult>.value(_SyncAccumulator(null).result);
    }
    final operation = _runTail.then((_) async {
      final result = _SyncAccumulator(userId);
      try {
        _requireExpectedUser(userId);
        await action(userId, result);
      } on SyncAccountChangedException catch (error) {
        result.markAccountChanged(error);
      } catch (error) {
        result.addIssue(unhandledPhase, error);
      }
      return result.result;
    });
    _runTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _pullLatest(String userId, _SyncAccumulator result) async {
    final now = DateTime.now();
    if (!trainingSyncEnabled) {
      try {
        final remoteWorkouts = await _remoteCall(
          userId,
          () => _remote.getWorkoutLogsForMonth(now),
        );
        if (remoteWorkouts.isNotEmpty) {
          await _localCall(
            userId,
            () => _local.saveWorkoutLogs(userId, remoteWorkouts),
          );
        }
      } on SyncAccountChangedException {
        rethrow;
      } catch (error) {
        result.addIssue('legacy-workout-pull', error);
      }
    }

    try {
      final remoteDiets = await _remoteCall(
        userId,
        () => _remote.getDietLogs(now),
      );
      if (remoteDiets.isNotEmpty) {
        await _localCall(
          userId,
          () => _local.saveDietLogs(userId, remoteDiets),
        );
      }
    } on SyncAccountChangedException {
      rethrow;
    } catch (error) {
      result.addIssue('legacy-diet-pull', error);
    }

    if (trainingSyncEnabled) {
      await _pullTrainingSnapshots(userId, result);
    }
  }

  Future<void> _pushPending(String userId, _SyncAccumulator result) async {
    await _pushLegacyDeletes(userId, result);
    await _pushLegacyUpserts(userId, result);
    if (trainingSyncEnabled) {
      await _pushTrainingOutbox(userId, result);
    }
  }

  Future<void> _pushLegacyDeletes(
    String userId,
    _SyncAccumulator result,
  ) async {
    final syncedWorkoutDeletes = <String>{};
    for (final id in await _localCall(
      userId,
      () => _local.getPendingWorkoutDeletes(userId),
    )) {
      try {
        await _remoteCall(
          userId,
          () => _remote.deleteWorkoutLog(id, expectedUserId: userId),
        );
        syncedWorkoutDeletes.add(id);
      } on SyncAccountChangedException {
        rethrow;
      } catch (error) {
        result.addIssue('legacy-workout-delete', error, entityId: id);
      }
    }
    if (syncedWorkoutDeletes.isNotEmpty) {
      await _localCall(
        userId,
        () => _local.removePendingWorkoutDeletes(userId, syncedWorkoutDeletes),
      );
    }

    final syncedDietDeletes = <String>{};
    for (final id in await _localCall(
      userId,
      () => _local.getPendingDietDeletes(userId),
    )) {
      try {
        await _remoteCall(
          userId,
          () => _remote.deleteDietLog(id, expectedUserId: userId),
        );
        syncedDietDeletes.add(id);
      } on SyncAccountChangedException {
        rethrow;
      } catch (error) {
        result.addIssue('legacy-diet-delete', error, entityId: id);
      }
    }
    if (syncedDietDeletes.isNotEmpty) {
      await _localCall(
        userId,
        () => _local.removePendingDietDeletes(userId, syncedDietDeletes),
      );
    }
  }

  Future<void> _pushLegacyUpserts(
    String userId,
    _SyncAccumulator result,
  ) async {
    final syncedWorkouts = <String>{};
    for (final log in await _localCall(
      userId,
      () => _local.getUnsyncedWorkoutLogs(userId),
    )) {
      try {
        await _remoteCall(
          userId,
          () => _remote.addWorkoutLog(log, expectedUserId: userId),
        );
        syncedWorkouts.add(log.id);
      } on SyncAccountChangedException {
        rethrow;
      } catch (error) {
        result.addIssue('legacy-workout-upsert', error, entityId: log.id);
      }
    }
    if (syncedWorkouts.isNotEmpty) {
      await _localCall(
        userId,
        () => _local.removeUnsyncedWorkoutLogs(userId, syncedWorkouts),
      );
    }

    final syncedDiets = <String>{};
    for (final log in await _localCall(
      userId,
      () => _local.getUnsyncedDietLogs(userId),
    )) {
      try {
        await _remoteCall(
          userId,
          () => _remote.addDietLog(log, expectedUserId: userId),
        );
        syncedDiets.add(log.id);
      } on SyncAccountChangedException {
        rethrow;
      } catch (error) {
        result.addIssue('legacy-diet-upsert', error, entityId: log.id);
      }
    }
    if (syncedDiets.isNotEmpty) {
      await _localCall(
        userId,
        () => _local.removeUnsyncedDietLogs(userId, syncedDiets),
      );
    }
  }

  Future<void> _pushTrainingOutbox(
    String userId,
    _SyncAccumulator result,
  ) async {
    try {
      await _localCall(
        userId,
        () => _local.bootstrapTrainingSyncOutbox(userId),
      );
    } on SyncAccountChangedException {
      rethrow;
    } catch (error) {
      result.addIssue('training-bootstrap', error);
      return;
    }

    final mutations =
        await _localCall(userId, () => _local.getTrainingSyncOutbox(userId))
          ..sort((a, b) => _mutationOrder(a).compareTo(_mutationOrder(b)));

    for (final mutation in mutations) {
      try {
        _validateSyncableMutation(mutation);
        await _pushTrainingMutation(userId, mutation);
        await _localCall(
          userId,
          () => _local.acknowledgeTrainingSyncMutation(
            userId,
            domain: mutation.domain,
            entityId: mutation.entityId,
            token: mutation.token,
          ),
        );
        result.trainingMutationsPushed++;
      } on SyncAccountChangedException {
        rethrow;
      } on UnsyncableTrainingMutationException catch (error) {
        await _localCall(
          userId,
          () => _local.acknowledgeTrainingSyncMutation(
            userId,
            domain: mutation.domain,
            entityId: mutation.entityId,
            token: mutation.token,
          ),
        );
        result.addIssue(
          'training-quarantine',
          error,
          domain: mutation.domain,
          entityId: mutation.entityId,
        );
      } catch (error) {
        result.addIssue(
          'training-push',
          error,
          domain: mutation.domain,
          entityId: mutation.entityId,
        );
      }
    }
  }

  Future<void> _pushTrainingMutation(
    String userId,
    TrainingSyncMutation mutation,
  ) {
    if (mutation.operation == TrainingSyncOperation.delete) {
      return switch (mutation.domain) {
        TrainingSyncDomain.program => _remoteCall(
          userId,
          () => _remote.deleteTrainingProgram(
            mutation.entityId,
            expectedUserId: userId,
          ),
        ),
        TrainingSyncDomain.rule => _remoteCall(
          userId,
          () => _remote.deleteProgressionRule(
            mutation.entityId,
            expectedUserId: userId,
          ),
        ),
        TrainingSyncDomain.workout => _remoteCall(
          userId,
          () => _remote.deleteWorkoutLog(
            mutation.entityId,
            expectedUserId: userId,
          ),
        ),
        TrainingSyncDomain.setLog => _remoteCall(
          userId,
          () => _remote.deleteWorkoutSetLog(
            mutation.entityId,
            expectedUserId: userId,
          ),
        ),
      };
    }
    return switch (mutation.domain) {
      TrainingSyncDomain.program => _remoteCall(
        userId,
        () => _remote.upsertTrainingProgram(
          mutation.decodeProgram(),
          expectedUserId: userId,
        ),
      ),
      TrainingSyncDomain.rule => _remoteCall(
        userId,
        () => _remote.upsertProgressionRule(
          mutation.decodeRule(),
          expectedUserId: userId,
        ),
      ),
      TrainingSyncDomain.workout => _remoteCall(
        userId,
        () => _remote.upsertWorkoutLog(
          mutation.decodeWorkout(),
          expectedUserId: userId,
        ),
      ),
      TrainingSyncDomain.setLog => _remoteCall(
        userId,
        () => _remote.upsertWorkoutSetLog(
          mutation.decodeSetLog(),
          expectedUserId: userId,
        ),
      ),
    };
  }

  Future<void> _pullTrainingSnapshots(
    String userId,
    _SyncAccumulator result,
  ) async {
    await _quarantineUnsyncableMutations(userId, result);
    await _pullTrainingDomain(
      userId,
      result,
      TrainingSyncDomain.program,
      load: _remote.getAllTrainingPrograms,
      replace: (items) =>
          _local.replaceTrainingProgramsFromSyncIfNoPending(userId, items),
    );
    await _pullTrainingDomain(
      userId,
      result,
      TrainingSyncDomain.rule,
      load: _remote.getAllProgressionRules,
      replace: (items) =>
          _local.replaceProgressionRulesFromSyncIfNoPending(userId, items),
    );
    await _pullTrainingDomain(
      userId,
      result,
      TrainingSyncDomain.workout,
      load: _remote.getAllWorkoutLogs,
      replace: (items) =>
          _local.replaceWorkoutLogsFromSyncIfNoPending(userId, items),
    );
    await _pullTrainingDomain(
      userId,
      result,
      TrainingSyncDomain.setLog,
      load: _remote.getAllWorkoutSetLogs,
      replace: (items) =>
          _local.replaceWorkoutSetLogsFromSyncIfNoPending(userId, items),
    );
  }

  Future<void> _quarantineUnsyncableMutations(
    String userId,
    _SyncAccumulator result,
  ) async {
    final pending = await _localCall(
      userId,
      () => _local.getTrainingSyncOutbox(userId),
    );
    for (final mutation in pending) {
      try {
        _validateSyncableMutation(mutation);
      } on UnsyncableTrainingMutationException catch (error) {
        await _localCall(
          userId,
          () => _local.acknowledgeTrainingSyncMutation(
            userId,
            domain: mutation.domain,
            entityId: mutation.entityId,
            token: mutation.token,
          ),
        );
        result.addIssue(
          'training-quarantine',
          error,
          domain: mutation.domain,
          entityId: mutation.entityId,
        );
      }
    }
  }

  Future<void> _pullTrainingDomain<T>(
    String userId,
    _SyncAccumulator result,
    TrainingSyncDomain domain, {
    required Future<List<T>> Function() load,
    required Future<bool> Function(List<T> items) replace,
  }) async {
    try {
      final items = await _remoteCall(userId, load);
      final replaced = await _localCall(userId, () => replace(items));
      if (replaced) result.trainingDomainsPulled.add(domain);
    } on SyncAccountChangedException {
      rethrow;
    } catch (error) {
      result.addIssue('training-pull', error, domain: domain);
    }
  }

  Future<T> _remoteCall<T>(
    String expectedUserId,
    Future<T> Function() action,
  ) async {
    _requireExpectedUser(expectedUserId);
    final value = await action();
    _requireExpectedUser(expectedUserId);
    return value;
  }

  Future<T> _localCall<T>(
    String expectedUserId,
    Future<T> Function() action,
  ) async {
    _requireExpectedUser(expectedUserId);
    final value = await action();
    _requireExpectedUser(expectedUserId);
    return value;
  }

  void _requireExpectedUser(String expectedUserId) {
    final actualUserId = _remote.userId;
    if (actualUserId != expectedUserId) {
      throw SyncAccountChangedException(expectedUserId, actualUserId);
    }
  }
}

int _mutationOrder(TrainingSyncMutation mutation) {
  return switch ((mutation.operation, mutation.domain)) {
    (TrainingSyncOperation.upsert, TrainingSyncDomain.program) => 0,
    // A rule can change ids while retaining its unique exercise identity.
    (TrainingSyncOperation.delete, TrainingSyncDomain.rule) => 1,
    (TrainingSyncOperation.upsert, TrainingSyncDomain.rule) => 2,
    (TrainingSyncOperation.upsert, TrainingSyncDomain.workout) => 3,
    (TrainingSyncOperation.upsert, TrainingSyncDomain.setLog) => 4,
    (TrainingSyncOperation.delete, TrainingSyncDomain.setLog) => 5,
    (TrainingSyncOperation.delete, TrainingSyncDomain.workout) => 6,
    (TrainingSyncOperation.delete, TrainingSyncDomain.program) => 7,
  };
}

void _validateSyncableMutation(TrainingSyncMutation mutation) {
  if (mutation.domain == TrainingSyncDomain.workout &&
      !_uuidPattern.hasMatch(mutation.entityId)) {
    throw UnsyncableTrainingMutationException(
      domain: mutation.domain,
      entityId: mutation.entityId,
      reason: 'the remote workout id column requires a UUID',
    );
  }
  if (mutation.domain == TrainingSyncDomain.workout &&
      mutation.operation == TrainingSyncOperation.upsert) {
    final workout = mutation.decodeWorkout();
    final slot = [
      workout.programId,
      workout.programDayId,
      workout.programExerciseId,
    ];
    if (workout.exerciseId.isEmpty ||
        slot.any((value) => value != null && value.isEmpty)) {
      throw UnsyncableTrainingMutationException(
        domain: mutation.domain,
        entityId: mutation.entityId,
        reason: 'legacy workout identifiers must stay local-only',
      );
    }
  }
  if (mutation.domain == TrainingSyncDomain.rule &&
      mutation.operation == TrainingSyncOperation.upsert &&
      mutation.decodeRule().exerciseId.isEmpty) {
    throw UnsyncableTrainingMutationException(
      domain: mutation.domain,
      entityId: mutation.entityId,
      reason: 'the remote progression rule requires an exercise id',
    );
  }
  if (mutation.domain == TrainingSyncDomain.setLog &&
      mutation.operation == TrainingSyncOperation.upsert) {
    final setLog = mutation.decodeSetLog();
    final parentWorkoutId = setLog.workoutLogId;
    if (!_uuidPattern.hasMatch(parentWorkoutId)) {
      throw UnsyncableTrainingMutationException(
        domain: mutation.domain,
        entityId: mutation.entityId,
        reason: 'the parent remote workout id requires a UUID',
      );
    }
    if (setLog.programDayId == null || setLog.programDayId!.isEmpty) {
      throw UnsyncableTrainingMutationException(
        domain: mutation.domain,
        entityId: mutation.entityId,
        reason: 'legacy set logs without a program day stay local-only',
      );
    }
    if (setLog.programId.isEmpty || setLog.programExerciseId.isEmpty) {
      throw UnsyncableTrainingMutationException(
        domain: mutation.domain,
        entityId: mutation.entityId,
        reason: 'legacy set logs with incomplete slots stay local-only',
      );
    }
  }
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class _SyncAccumulator {
  final String? userId;
  int trainingMutationsPushed = 0;
  final Set<TrainingSyncDomain> trainingDomainsPulled = {};
  final List<SyncIssue> issues = [];
  bool accountChanged = false;

  _SyncAccumulator(this.userId);

  void addIssue(
    String phase,
    Object error, {
    TrainingSyncDomain? domain,
    String? entityId,
  }) {
    issues.add(
      SyncIssue(phase: phase, error: error, domain: domain, entityId: entityId),
    );
  }

  void markAccountChanged(SyncAccountChangedException error) {
    accountChanged = true;
    addIssue('account-changed', error);
  }

  SyncRunResult get result => SyncRunResult(
    userId: userId,
    trainingMutationsPushed: trainingMutationsPushed,
    trainingDomainsPulled: Set.unmodifiable(trainingDomainsPulled),
    issues: List.unmodifiable(issues),
    accountChanged: accountChanged,
  );
}

class _SupabaseSyncGateway implements SyncRemoteGateway {
  final SupabaseService _service;

  const _SupabaseSyncGateway(this._service);

  @override
  String? get userId => _service.userId;

  @override
  Future<void> addDietLog(DietLog log, {required String expectedUserId}) =>
      _service.addDietLogForSync(log, expectedUserId: expectedUserId);

  @override
  Future<void> addWorkoutLog(
    WorkoutLog log, {
    required String expectedUserId,
  }) => _service.addWorkoutLogForSync(log, expectedUserId: expectedUserId);

  @override
  Future<void> deleteDietLog(String logId, {required String expectedUserId}) =>
      _service.deleteDietLogForSync(logId, expectedUserId: expectedUserId);

  @override
  Future<void> deleteProgressionRule(
    String ruleId, {
    required String expectedUserId,
  }) => _service.deleteProgressionRuleForSync(
    ruleId,
    expectedUserId: expectedUserId,
  );

  @override
  Future<void> deleteTrainingProgram(
    String programId, {
    required String expectedUserId,
  }) => _service.deleteTrainingProgramForSync(
    programId,
    expectedUserId: expectedUserId,
  );

  @override
  Future<void> deleteWorkoutLog(
    String logId, {
    required String expectedUserId,
  }) => _service.deleteWorkoutLogForSync(logId, expectedUserId: expectedUserId);

  @override
  Future<void> deleteWorkoutSetLog(
    String setLogId, {
    required String expectedUserId,
  }) => _service.deleteWorkoutSetLogForSync(
    setLogId,
    expectedUserId: expectedUserId,
  );

  @override
  Future<List<DietLog>> getDietLogs(DateTime date) =>
      _service.getDietLogs(date);

  @override
  Future<List<ProgressionRule>> getAllProgressionRules() =>
      _service.getAllProgressionRules();

  @override
  Future<List<TrainingProgram>> getAllTrainingPrograms() =>
      _service.getAllTrainingPrograms();

  @override
  Future<List<WorkoutLog>> getAllWorkoutLogs() => _service.getAllWorkoutLogs();

  @override
  Future<List<WorkoutSetLog>> getAllWorkoutSetLogs() =>
      _service.getAllWorkoutSetLogs();

  @override
  Future<List<WorkoutLog>> getWorkoutLogsForMonth(DateTime month) =>
      _service.getWorkoutLogsForMonth(month);

  @override
  Future<void> upsertProgressionRule(
    ProgressionRule rule, {
    required String expectedUserId,
  }) => _service.upsertProgressionRuleForSync(
    rule,
    expectedUserId: expectedUserId,
  );

  @override
  Future<void> upsertTrainingProgram(
    TrainingProgram program, {
    required String expectedUserId,
  }) => _service.upsertTrainingProgramForSync(
    program,
    expectedUserId: expectedUserId,
  );

  @override
  Future<void> upsertWorkoutLog(
    WorkoutLog log, {
    required String expectedUserId,
  }) => _service.upsertWorkoutLogForSync(log, expectedUserId: expectedUserId);

  @override
  Future<void> upsertWorkoutSetLog(
    WorkoutSetLog log, {
    required String expectedUserId,
  }) =>
      _service.upsertWorkoutSetLogForSync(log, expectedUserId: expectedUserId);
}

class _AppDatabaseSyncGateway implements SyncLocalGateway {
  final AppDatabase _database;

  const _AppDatabaseSyncGateway(this._database);

  @override
  Future<void> acknowledgeTrainingSyncMutation(
    String userId, {
    required TrainingSyncDomain domain,
    required String entityId,
    required String token,
  }) => _database.acknowledgeTrainingSyncMutation(
    userId,
    domain: domain,
    entityId: entityId,
    token: token,
  );

  @override
  Future<void> bootstrapTrainingSyncOutbox(String userId) =>
      _database.bootstrapTrainingSyncOutbox(userId);

  @override
  Future<List<String>> getPendingDietDeletes(String userId) =>
      _database.getPendingDietDeletes(userId);

  @override
  Future<List<String>> getPendingWorkoutDeletes(String userId) =>
      _database.getPendingWorkoutDeletes(userId);

  @override
  Future<List<TrainingSyncMutation>> getTrainingSyncOutbox(String userId) =>
      _database.getTrainingSyncOutbox(userId);

  @override
  Future<List<DietLog>> getUnsyncedDietLogs(String userId) =>
      _database.getUnsyncedDietLogs(userId);

  @override
  Future<List<WorkoutLog>> getUnsyncedWorkoutLogs(String userId) =>
      _database.getUnsyncedWorkoutLogs(userId);

  @override
  Future<void> removePendingDietDeletes(String userId, Set<String> ids) =>
      _database.removePendingDietDeletes(userId, ids);

  @override
  Future<void> removePendingWorkoutDeletes(String userId, Set<String> ids) =>
      _database.removePendingWorkoutDeletes(userId, ids);

  @override
  Future<void> removeUnsyncedDietLogs(String userId, Set<String> ids) =>
      _database.removeUnsyncedDietLogs(userId, ids);

  @override
  Future<void> removeUnsyncedWorkoutLogs(String userId, Set<String> ids) =>
      _database.removeUnsyncedWorkoutLogs(userId, ids);

  @override
  Future<bool> replaceProgressionRulesFromSyncIfNoPending(
    String userId,
    List<ProgressionRule> rules,
  ) => _database.replaceProgressionRulesFromSyncIfNoPending(userId, rules);

  @override
  Future<bool> replaceTrainingProgramsFromSyncIfNoPending(
    String userId,
    List<TrainingProgram> programs,
  ) => _database.replaceTrainingProgramsFromSyncIfNoPending(userId, programs);

  @override
  Future<bool> replaceWorkoutLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutLog> logs,
  ) => _database.replaceWorkoutLogsFromSyncIfNoPending(userId, logs);

  @override
  Future<bool> replaceWorkoutSetLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutSetLog> logs,
  ) => _database.replaceWorkoutSetLogsFromSyncIfNoPending(userId, logs);

  @override
  Future<void> saveDietLogs(String userId, List<DietLog> logs) =>
      _database.saveDietLogs(userId, logs);

  @override
  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs) =>
      _database.saveWorkoutLogs(userId, logs);
}
