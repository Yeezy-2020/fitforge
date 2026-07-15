import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/training_sync.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/food.dart';
import '../models/diet_log.dart';
import '../models/user_profile.dart';
import '../models/workout_template.dart';
import '../models/body_measurement.dart';
import '../models/progression_rule.dart';
import '../models/training_program.dart';
import 'exercise_library.dart';

class UnsupportedStorageVersionException implements Exception {
  final int schemaVersion;
  final String blobType;

  const UnsupportedStorageVersionException(
    this.schemaVersion, [
    this.blobType = 'training program',
  ]);

  @override
  String toString() =>
      'UnsupportedStorageVersionException: Unsupported $blobType '
      'storage schema version $schemaVersion.';
}

class CorruptStorageDataException implements Exception {
  final String message;

  const CorruptStorageDataException(this.message);

  @override
  String toString() => 'CorruptStorageDataException: $message';
}

class AppDatabase {
  static const _storageSchemaVersion = 1;
  static const _trainingProgramsType = 'training_programs';
  static const _workoutLogsType = 'workout_logs';
  static const _workoutSetLogsType = 'workout_set_logs';
  static const _progressionRulesType = 'progression_rules';
  static const _trainingSyncOutboxType = 'training_sync_outbox';
  static const _trainingSyncBootstrapType = 'training_sync_bootstrap_v1';
  static const _trainingSyncRecoveryType = 'training_sync_recovery_v1';
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Map<String, Future<void>> _mutationTails = {};
  final bool trainingSyncEnabled;
  final Future<void> Function(String key)? _beforeTrainingSyncMetadataWrite;

  AppDatabase._({
    this.trainingSyncEnabled = trainingSyncV1Enabled,
    this._beforeTrainingSyncMetadataWrite,
  });
  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase.forTesting({
    required bool trainingSyncEnabled,
    Future<void> Function(String key)? beforeTrainingSyncMetadataWrite,
  }) => AppDatabase._(
    trainingSyncEnabled: trainingSyncEnabled,
    beforeTrainingSyncMetadataWrite: beforeTrainingSyncMetadataWrite,
  );

  String _key(String userId, String type) => '$userId:$type';

  Future<T> _withMutationLock<T>(
    String storageKey,
    Future<T> Function() mutation,
  ) {
    final previous = _mutationTails[storageKey] ?? Future<void>.value();
    final operation = previous.then<T>((_) => mutation());
    late final Future<void> tail;
    tail = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() {
          if (identical(_mutationTails[storageKey], tail)) {
            _mutationTails.remove(storageKey);
          }
        });
    _mutationTails[storageKey] = tail;
    return operation;
  }

  Future<T> _withWorkoutAndSetMutationLocks<T>(
    String userId,
    Future<T> Function() mutation,
  ) {
    return _withMutationLock(
      _key(userId, _workoutLogsType),
      () => _withMutationLock(_key(userId, _workoutSetLogsType), mutation),
    );
  }

  Future<List<T>> _readStoredList<T>(
    String userId, {
    required String storageType,
    required String blobLabel,
    required T Function(Map<String, dynamic>) decodeItem,
    required String? Function(T) invalidItemReason,
  }) async {
    if (userId.isEmpty) return [];
    final raw = await _storage.read(key: _key(userId, storageType));
    if (raw == null) return [];

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw CorruptStorageDataException(
        'Stored $blobLabel data is not valid JSON.',
      );
    }

    final List<dynamic> data;
    if (decoded is List) {
      data = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion is! int) {
        throw CorruptStorageDataException(
          '$blobLabel storage has an invalid schema version.',
        );
      }
      if (schemaVersion != _storageSchemaVersion) {
        throw UnsupportedStorageVersionException(schemaVersion, blobLabel);
      }
      final envelopeData = decoded['data'];
      if (envelopeData is! List) {
        throw CorruptStorageDataException(
          '$blobLabel storage has invalid data.',
        );
      }
      data = envelopeData;
    } else {
      throw CorruptStorageDataException(
        '$blobLabel storage must contain a list or versioned object.',
      );
    }

    final items = <T>[];
    for (final itemData in data) {
      if (itemData is! Map<String, dynamic>) {
        throw CorruptStorageDataException(
          '$blobLabel storage contains an invalid item.',
        );
      }
      final T item;
      try {
        item = decodeItem(itemData);
      } catch (_) {
        throw CorruptStorageDataException(
          '$blobLabel storage contains an invalid item.',
        );
      }
      final invalidReason = invalidItemReason(item);
      if (invalidReason != null) {
        throw CorruptStorageDataException('$blobLabel storage $invalidReason.');
      }
      items.add(item);
    }
    return items;
  }

  Future<void> _writeStoredListV1<T>(
    String userId, {
    required String storageType,
    required List<T> items,
    required Map<String, dynamic> Function(T) encodeItem,
  }) {
    return _storage.write(
      key: _key(userId, storageType),
      value: jsonEncode({
        'schemaVersion': _storageSchemaVersion,
        'data': items.map(encodeItem).toList(),
      }),
    );
  }

  void _validateUserId(String userId) {
    if (userId.isEmpty) {
      throw ArgumentError('A non-empty userId is required.');
    }
  }

  Future<List<Exercise>> getExercises(String userId) async {
    final data = await _storage.read(key: _key(userId, 'exercises'));
    if (data == null) return ExerciseLibrary.defaultExercises;
    final stored = (jsonDecode(data) as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return stored.isNotEmpty ? stored : ExerciseLibrary.defaultExercises;
  }

  Future<void> saveExercises(String userId, List<Exercise> exercises) async {
    final snapshot = List<Exercise>.of(exercises);
    await _withMutationLock(_key(userId, 'exercises'), () async {
      await _writeExercises(userId, snapshot);
    });
  }

  Future<void> _writeExercises(String userId, List<Exercise> exercises) async {
    await _storage.write(
      key: _key(userId, 'exercises'),
      value: jsonEncode(exercises.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addExercise(String userId, Exercise exercise) async {
    await _withMutationLock(_key(userId, 'exercises'), () async {
      final exercises = await getExercises(userId);
      exercises.add(exercise);
      await _writeExercises(userId, exercises);
    });
  }

  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async {
    final dateStr = _dateStr(date);
    return (await _getAllWorkoutLogs(
      userId,
    )).where((log) => _dateStr(log.date) == dateStr).toList();
  }

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async {
    final monthStr =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return (await _getAllWorkoutLogs(
      userId,
    )).where((log) => _dateStr(log.date).startsWith(monthStr)).toList();
  }

  Future<void> addWorkoutLog(String userId, WorkoutLog log) async {
    _validateWorkoutLogWrite(userId, [log]);
    await _withWorkoutAndSetMutationLocks(userId, () async {
      final logs = await _getAllWorkoutLogs(userId);
      final index = logs.indexWhere((item) => item.id == log.id);
      if (index >= 0) {
        final hasSets = (await _getAllWorkoutSetLogs(
          userId,
        )).any((setLog) => setLog.workoutLogId == log.id);
        if (hasSets && !_hasSameWorkoutSetParentIdentity(logs[index], log)) {
          throw StateError(
            'Workout log ${log.id} cannot change its exercise or program '
            'slot while workout sets reference it.',
          );
        }
      }
      await _preflightTrainingSyncOutbox(userId);
      await _stageTrainingSyncRecovery(userId, TrainingSyncDomain.workout, [
        log.id,
      ]);
      if (index >= 0) {
        logs[index] = log;
      } else {
        logs.add(log);
      }
      await _writeWorkoutLogsV1(userId, logs);
      await _enqueueTrainingSyncUpsert(
        userId,
        TrainingSyncDomain.workout,
        log.id,
        log.toJson(),
      );
    });
  }

  bool _hasSameWorkoutSetParentIdentity(WorkoutLog previous, WorkoutLog next) =>
      previous.exerciseId == next.exerciseId &&
      previous.programId == next.programId &&
      previous.programDayId == next.programDayId &&
      previous.programExerciseId == next.programExerciseId;

  Future<void> deleteWorkoutLog(String userId, String logId) async {
    _validateUserId(userId);
    await _withWorkoutAndSetMutationLocks(userId, () async {
      await _preflightTrainingSyncOutbox(userId);
      await _stageTrainingSyncRecovery(userId, TrainingSyncDomain.workout, [
        logId,
      ]);
      final logs = await _getAllWorkoutLogs(userId);
      final setLogs = await _getAllWorkoutSetLogs(userId);
      final deletedSets = setLogs
          .where((setLog) => setLog.workoutLogId == logId)
          .toList();
      if (deletedSets.isNotEmpty) {
        await _stageTrainingSyncRecovery(
          userId,
          TrainingSyncDomain.setLog,
          deletedSets
              .where(_isRemotelySyncableSetLog)
              .map((setLog) => setLog.id),
        );
        setLogs.removeWhere((setLog) => setLog.workoutLogId == logId);
        await _writeWorkoutSetLogsV1(userId, setLogs);
        for (final setLog in deletedSets) {
          if (_isRemotelySyncableSetLog(setLog)) {
            await _enqueueTrainingSyncDelete(
              userId,
              TrainingSyncDomain.setLog,
              setLog.id,
            );
          }
        }
      }
      logs.removeWhere((log) => log.id == logId);
      await _writeWorkoutLogsV1(userId, logs);
      await _enqueueTrainingSyncDelete(
        userId,
        TrainingSyncDomain.workout,
        logId,
      );
    });
  }

  Future<List<WorkoutLog>> _getAllWorkoutLogs(String userId) => _readStoredList(
    userId,
    storageType: _workoutLogsType,
    blobLabel: 'workout log',
    decodeItem: WorkoutLog.fromJson,
    invalidItemReason: (log) => _invalidWorkoutLogReason(userId, log),
  );

  String? _invalidWorkoutLogReason(String userId, WorkoutLog log) {
    if (log.userId != userId) return 'contains data for a different user';
    if (log.id.isEmpty || log.exerciseId.isEmpty) {
      return 'contains an item with invalid identifiers';
    }
    final slotIds = [log.programId, log.programDayId, log.programExerciseId];
    final hasAnySlot = slotIds.any((value) => value != null);
    if (hasAnySlot && slotIds.any((value) => value == null || value.isEmpty)) {
      return 'contains an item with an invalid program slot';
    }
    return null;
  }

  void _validateWorkoutLogWrite(String userId, List<WorkoutLog> logs) {
    _validateUserId(userId);
    if (logs.any((log) => log.userId != userId)) {
      throw ArgumentError('Every workout log must belong to the storage user.');
    }
    if (logs.any((log) => _invalidWorkoutLogReason(userId, log) != null)) {
      throw ArgumentError('Every workout log must contain valid identifiers.');
    }
  }

  Future<void> _writeWorkoutLogsV1(String userId, List<WorkoutLog> logs) {
    _validateWorkoutLogWrite(userId, logs);
    return _writeStoredListV1(
      userId,
      storageType: _workoutLogsType,
      items: logs,
      encodeItem: (log) => log.toJson(),
    );
  }

  Future<WorkoutLog?> getLastWorkoutLogForExercise(
    String userId,
    String exerciseId,
    DateTime beforeDate,
  ) async {
    final logs = await _getAllWorkoutLogs(userId);
    final matches =
        logs
            .where(
              (l) => l.exerciseId == exerciseId && l.date.isBefore(beforeDate),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return matches.isNotEmpty ? matches.first : null;
  }

  // ---- Progression Rules ----
  Future<List<ProgressionRule>> getProgressionRules(String userId) =>
      _readStoredList(
        userId,
        storageType: _progressionRulesType,
        blobLabel: 'progression rule',
        decodeItem: ProgressionRule.fromJson,
        invalidItemReason: (rule) =>
            _invalidProgressionRuleReason(userId, rule),
      );

  String? _invalidProgressionRuleReason(String userId, ProgressionRule rule) {
    if (rule.userId != userId) return 'contains data for a different user';
    if (rule.id.isEmpty || rule.exerciseId.isEmpty) {
      return 'contains an item with invalid identifiers';
    }
    return null;
  }

  void _validateProgressionRuleWrite(
    String userId,
    List<ProgressionRule> rules,
  ) {
    _validateUserId(userId);
    if (rules.any((rule) => rule.userId != userId)) {
      throw ArgumentError(
        'Every progression rule must belong to the storage user.',
      );
    }
    if (rules.any(
      (rule) => _invalidProgressionRuleReason(userId, rule) != null,
    )) {
      throw ArgumentError(
        'Every progression rule must contain valid identifiers.',
      );
    }
  }

  Future<void> _writeProgressionRulesV1(
    String userId,
    List<ProgressionRule> rules,
  ) {
    _validateProgressionRuleWrite(userId, rules);
    return _writeStoredListV1(
      userId,
      storageType: _progressionRulesType,
      items: rules,
      encodeItem: (rule) => rule.toJson(),
    );
  }

  Future<ProgressionRule?> getProgressionRule(
    String userId,
    String exerciseId,
  ) async {
    final rules = await getProgressionRules(userId);
    for (final rule in rules) {
      if (rule.exerciseId == exerciseId) return rule;
    }
    return null;
  }

  Future<void> saveProgressionRule(String userId, ProgressionRule rule) async {
    _validateProgressionRuleWrite(userId, [rule]);
    final storageKey = _key(userId, _progressionRulesType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final rules = await getProgressionRules(userId);
      final idx = rules.indexWhere(
        (item) => item.exerciseId == rule.exerciseId,
      );
      final replacedId = idx >= 0 ? rules[idx].id : null;
      if (idx >= 0) {
        rules[idx] = rule;
      } else {
        rules.add(rule);
      }
      await _stageTrainingSyncRecovery(userId, TrainingSyncDomain.rule, [
        rule.id,
        if (replacedId != null && replacedId != rule.id) replacedId,
      ]);
      await _writeProgressionRulesV1(userId, rules);
      if (replacedId != null && replacedId != rule.id) {
        await _enqueueTrainingSyncDelete(
          userId,
          TrainingSyncDomain.rule,
          replacedId,
        );
      }
      await _enqueueTrainingSyncUpsert(
        userId,
        TrainingSyncDomain.rule,
        rule.id,
        rule.toJson(),
      );
    });
  }

  Future<void> deleteProgressionRule(String userId, String exerciseId) async {
    _validateUserId(userId);
    final storageKey = _key(userId, _progressionRulesType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final rules = await getProgressionRules(userId);
      final deletedIds = rules
          .where((rule) => rule.exerciseId == exerciseId)
          .map((rule) => rule.id)
          .toList();
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.rule,
        deletedIds,
      );
      rules.removeWhere((rule) => rule.exerciseId == exerciseId);
      await _writeProgressionRulesV1(userId, rules);
      for (final id in deletedIds) {
        await _enqueueTrainingSyncDelete(userId, TrainingSyncDomain.rule, id);
      }
    });
  }

  // ---- Training Programs ----

  Future<List<TrainingProgram>> getTrainingPrograms(String userId) =>
      _readStoredList(
        userId,
        storageType: _trainingProgramsType,
        blobLabel: 'training program',
        decodeItem: TrainingProgram.fromJson,
        invalidItemReason: (program) => program.userId == userId
            ? null
            : 'contains data for a different user',
      );

  void _validateTrainingProgramWrite(
    String userId,
    List<TrainingProgram> programs,
  ) {
    _validateUserId(userId);
    if (programs.any((program) => program.userId != userId)) {
      throw ArgumentError(
        'Every training program must belong to the storage user.',
      );
    }
  }

  Future<void> _writeTrainingProgramsV1(
    String userId,
    List<TrainingProgram> programs,
  ) async {
    _validateTrainingProgramWrite(userId, programs);
    await _writeStoredListV1(
      userId,
      storageType: _trainingProgramsType,
      items: programs,
      encodeItem: (program) => program.toJson(),
    );
  }

  List<TrainingProgram> _normalizeActiveTrainingPrograms(
    List<TrainingProgram> programs,
  ) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final withMetadata = programs
        .map((program) => _withActivationMetadata(program, now))
        .toList();

    TrainingProgram? currentProgram;
    DateTime? currentStart;
    TrainingProgram? futureProgram;
    DateTime? futureStart;

    for (final program in withMetadata) {
      if (!program.active) continue;
      final start = _dateOnly(program.activatedAt ?? program.updatedAt);
      if (start.isAfter(today)) {
        if (futureProgram == null ||
            program.updatedAt.isAfter(futureProgram.updatedAt) ||
            (program.updatedAt == futureProgram.updatedAt &&
                start.isAfter(futureStart!))) {
          futureProgram = program;
          futureStart = start;
        }
        continue;
      }

      if (currentProgram == null ||
          start.isAfter(currentStart!) ||
          (start == currentStart &&
              program.updatedAt.isAfter(currentProgram.updatedAt))) {
        currentProgram = program;
        currentStart = start;
      }
    }

    return withMetadata.map((program) {
      if (!program.active) return program;
      final keep =
          program.id == currentProgram?.id || program.id == futureProgram?.id;
      return keep ? program : program.copyWith(active: false);
    }).toList();
  }

  TrainingProgram _withActivationMetadata(
    TrainingProgram program,
    DateTime activatedAt,
  ) {
    if (!program.active || program.activatedAt != null) return program;
    return program.copyWith(
      activatedAt: activatedAt,
      activatedDayIndex: program.normalizedCurrentDayIndex,
    );
  }

  Future<void> saveTrainingPrograms(
    String userId,
    List<TrainingProgram> programs,
  ) async {
    _validateTrainingProgramWrite(userId, programs);
    final snapshot = List<TrainingProgram>.of(programs);
    final storageKey = _key(userId, _trainingProgramsType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final previous = await getTrainingPrograms(userId);
      final normalized = _normalizeActiveTrainingPrograms(snapshot);
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.program,
        _trainingProgramMutationIds(previous, normalized),
      );
      await _writeTrainingProgramsV1(userId, normalized);
      await _enqueueTrainingProgramSnapshot(userId, previous, normalized);
    });
  }

  Future<void> saveTrainingProgram(
    String userId,
    TrainingProgram program,
  ) async {
    _validateTrainingProgramWrite(userId, [program]);
    final storageKey = _key(userId, _trainingProgramsType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final programs = await getTrainingPrograms(userId);
      final previous = List<TrainingProgram>.of(programs);
      final idx = programs.indexWhere((item) => item.id == program.id);
      if (idx >= 0) {
        programs[idx] = program;
      } else {
        programs.add(program);
      }
      final now = DateTime.now();
      final normalized = program.active
          ? _normalizeActiveTrainingPrograms(
              programs
                  .map(
                    (item) => item.id == program.id
                        ? _withActivationMetadata(
                            item.copyWith(active: true),
                            now,
                          )
                        : item,
                  )
                  .toList(),
            )
          : _normalizeActiveTrainingPrograms(programs);
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.program,
        _trainingProgramMutationIds(previous, normalized),
      );
      await _writeTrainingProgramsV1(userId, normalized);
      await _enqueueTrainingProgramSnapshot(userId, previous, normalized);
    });
  }

  Future<void> deleteTrainingProgram(String userId, String programId) async {
    _validateTrainingProgramWrite(userId, const []);
    final storageKey = _key(userId, _trainingProgramsType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      await _stageTrainingSyncRecovery(userId, TrainingSyncDomain.program, [
        programId,
      ]);
      final programs = await getTrainingPrograms(userId);
      programs.removeWhere((program) => program.id == programId);
      await _writeTrainingProgramsV1(userId, programs);
      await _enqueueTrainingSyncDelete(
        userId,
        TrainingSyncDomain.program,
        programId,
      );
    });
  }

  Future<TrainingProgram?> getActiveTrainingProgram(String userId) async {
    final programs = await getTrainingPrograms(userId);
    return activeTrainingProgramForUser(programs, userId);
  }

  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) async {
    _validateTrainingProgramWrite(userId, const []);
    final storageKey = _key(userId, _trainingProgramsType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final programs = await getTrainingPrograms(userId);
      if (!programs.any((program) => program.id == programId)) return;
      final previous = List<TrainingProgram>.of(programs);
      final now = DateTime.now();
      final start = activatedAt ?? now;
      final futureActivation = _dateOnly(start).isAfter(_dateOnly(now));
      for (var i = 0; i < programs.length; i++) {
        final program = programs[i];
        final activating = program.id == programId;
        final shouldDeactivate =
            !activating &&
            program.active &&
            (!futureActivation ||
                _dateOnly(
                  program.activatedAt ?? program.updatedAt,
                ).isAfter(_dateOnly(now)));
        final updated = program.copyWith(
          active: activating
              ? true
              : shouldDeactivate
              ? false
              : program.active,
          activatedAt: activating ? start : program.activatedAt,
          activatedDayIndex: activating
              ? program.normalizedCurrentDayIndex
              : program.activatedDayIndex,
          plannedCycleCount: activating
              ? plannedCycleCount
              : program.plannedCycleCount,
          clearPlannedCycleCount: activating && plannedCycleCount == null,
          pausePeriods: activating ? const [] : program.pausePeriods,
          updatedAt: activating ? now : program.updatedAt,
        );
        programs[i] = activating
            ? _withActivationMetadata(updated, now)
            : updated;
      }
      final normalized = _normalizeActiveTrainingPrograms(programs);
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.program,
        _trainingProgramMutationIds(previous, normalized),
      );
      await _writeTrainingProgramsV1(userId, normalized);
      await _enqueueTrainingProgramSnapshot(userId, previous, normalized);
    });
  }

  Future<void> endTrainingProgram(String userId, String programId) async {
    _validateTrainingProgramWrite(userId, const []);
    final storageKey = _key(userId, _trainingProgramsType);
    await _withMutationLock(storageKey, () async {
      await _preflightTrainingSyncOutbox(userId);
      final programs = await getTrainingPrograms(userId);
      final idx = programs.indexWhere((program) => program.id == programId);
      if (idx < 0) return;
      final previous = List<TrainingProgram>.of(programs);
      final program = programs[idx];
      if (!program.active && program.pausePeriods.isEmpty) return;
      programs[idx] = program.endExecution();
      final normalized = _normalizeActiveTrainingPrograms(programs);
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.program,
        _trainingProgramMutationIds(previous, normalized),
      );
      await _writeTrainingProgramsV1(userId, normalized);
      await _enqueueTrainingProgramSnapshot(userId, previous, normalized);
    });
  }

  Future<void> saveWorkoutSetLogs(
    String userId,
    List<WorkoutSetLog> logs,
  ) async {
    _validateWorkoutSetLogWrite(userId, logs);
    final snapshot = List<WorkoutSetLog>.of(logs);
    await _withWorkoutAndSetMutationLocks(userId, () async {
      await _preflightTrainingSyncOutbox(userId);
      final existing = await _getAllWorkoutSetLogs(userId);
      final previousById = {for (final log in existing) log.id: log};
      final workoutIds = (await _getAllWorkoutLogs(
        userId,
      )).map((workout) => workout.id).toSet();
      final missingParent = snapshot.where((log) {
        final previous = previousById[log.id];
        final requiresParent =
            _uuidPattern.hasMatch(log.workoutLogId) ||
            (previous != null && _isRemotelySyncableSetLog(previous));
        return requiresParent && !workoutIds.contains(log.workoutLogId);
      }).firstOrNull;
      if (missingParent != null) {
        throw StateError(
          'Workout set ${missingParent.id} requires an existing workout log.',
        );
      }
      await _stageTrainingSyncRecovery(
        userId,
        TrainingSyncDomain.setLog,
        snapshot
            .where((log) {
              final previous = previousById[log.id];
              return _isRemotelySyncableSetLog(log) ||
                  (previous != null && _isRemotelySyncableSetLog(previous));
            })
            .map((log) => log.id),
      );
      for (final log in snapshot) {
        final idx = existing.indexWhere((item) => item.id == log.id);
        if (idx >= 0) {
          existing[idx] = log;
        } else {
          existing.add(log);
        }
      }
      await _writeWorkoutSetLogsV1(userId, existing);
      for (final log in snapshot) {
        final previous = previousById[log.id];
        if (_isRemotelySyncableSetLog(log)) {
          await _enqueueTrainingSyncUpsert(
            userId,
            TrainingSyncDomain.setLog,
            log.id,
            log.toJson(),
          );
        } else if (previous != null && _isRemotelySyncableSetLog(previous)) {
          await _enqueueTrainingSyncDelete(
            userId,
            TrainingSyncDomain.setLog,
            log.id,
          );
        }
      }
    });
  }

  Future<void> deleteWorkoutSetLog(String userId, String setLogId) async {
    _validateUserId(userId);
    await _withWorkoutAndSetMutationLocks(userId, () async {
      await _preflightTrainingSyncOutbox(userId);
      final logs = await _getAllWorkoutSetLogs(userId);
      final deleted = logs.where((log) => log.id == setLogId).firstOrNull;
      if (deleted != null && _isRemotelySyncableSetLog(deleted)) {
        await _stageTrainingSyncRecovery(userId, TrainingSyncDomain.setLog, [
          setLogId,
        ]);
      }
      logs.removeWhere((log) => log.id == setLogId);
      await _writeWorkoutSetLogsV1(userId, logs);
      if (deleted != null && _isRemotelySyncableSetLog(deleted)) {
        await _enqueueTrainingSyncDelete(
          userId,
          TrainingSyncDomain.setLog,
          setLogId,
        );
      }
    });
  }

  Future<List<WorkoutSetLog>> _getAllWorkoutSetLogs(String userId) =>
      _readStoredList(
        userId,
        storageType: _workoutSetLogsType,
        blobLabel: 'workout set log',
        decodeItem: WorkoutSetLog.fromJson,
        invalidItemReason: _invalidWorkoutSetLogReason,
      );

  String? _invalidWorkoutSetLogReason(WorkoutSetLog log) {
    if (log.id.isEmpty ||
        log.workoutLogId.isEmpty ||
        log.programId.isEmpty ||
        log.programExerciseId.isEmpty ||
        (log.programDayId != null && log.programDayId!.isEmpty)) {
      return 'contains an item with invalid program slot identifiers';
    }
    return null;
  }

  bool _isRemotelySyncableSetLog(WorkoutSetLog log) =>
      _uuidPattern.hasMatch(log.workoutLogId) &&
      log.programDayId != null &&
      log.programDayId!.isNotEmpty;

  void _validateWorkoutSetLogWrite(String userId, List<WorkoutSetLog> logs) {
    _validateUserId(userId);
    if (logs.any((log) => _invalidWorkoutSetLogReason(log) != null)) {
      throw ArgumentError(
        'Every workout set log must contain valid identifiers.',
      );
    }
  }

  Future<void> _writeWorkoutSetLogsV1(String userId, List<WorkoutSetLog> logs) {
    _validateWorkoutSetLogWrite(userId, logs);
    return _writeStoredListV1(
      userId,
      storageType: _workoutSetLogsType,
      items: logs,
      encodeItem: (log) => log.toJson(),
    );
  }

  Future<List<WorkoutSetLog>> getWorkoutSetLogs(
    String userId,
    String workoutLogId,
  ) async {
    return (await _getAllWorkoutSetLogs(
      userId,
    )).where((log) => log.workoutLogId == workoutLogId).toList();
  }

  Future<WorkoutLog?> getLastWorkoutLogForProgramExercise(
    String userId, {
    required String programId,
    required String programExerciseId,
    required DateTime beforeDate,
  }) async {
    final setLogs = (await _getAllWorkoutSetLogs(userId))
        .where(
          (log) =>
              log.programId == programId &&
              log.programExerciseId == programExerciseId,
        )
        .toList();
    if (setLogs.isEmpty) return null;

    final workoutLogIds = setLogs.map((log) => log.workoutLogId).toSet();
    final logs =
        (await _getAllWorkoutLogs(userId))
            .where(
              (log) =>
                  workoutLogIds.contains(log.id) &&
                  log.date.isBefore(beforeDate),
            )
            .toList()
          ..sort((a, b) {
            final dateCompare = b.date.compareTo(a.date);
            if (dateCompare != 0) return dateCompare;
            final aCreated =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bCreated =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bCreated.compareTo(aCreated);
          });
    return logs.isNotEmpty ? logs.first : null;
  }

  Future<List<DietLog>> getDietLogs(String userId, DateTime date) async {
    final dateStr = _dateStr(date);
    return (await _getAllDietLogs(
      userId,
    )).where((log) => _dateStr(log.date) == dateStr).toList();
  }

  Future<void> addDietLog(String userId, DietLog log) async {
    await _withMutationLock(_key(userId, 'diet_logs'), () async {
      final logs = await _getAllDietLogs(userId);
      logs.add(log);
      await _writeDietLogs(userId, logs);
    });
  }

  Future<void> deleteDietLog(String userId, String logId) async {
    final storageKey = _key(userId, 'diet_logs');
    await _withMutationLock(storageKey, () async {
      final data = await _storage.read(key: storageKey);
      if (data == null) return;
      final logs = _decodeDietLogs(data);
      logs.removeWhere((log) => log.id == logId);
      await _writeDietLogs(userId, logs);
    });
  }

  Future<List<DietLog>> _getAllDietLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'diet_logs'));
    if (data == null) return [];
    return _decodeDietLogs(data);
  }

  List<DietLog> _decodeDietLogs(String data) {
    return (jsonDecode(data) as List)
        .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeDietLogs(String userId, List<DietLog> logs) {
    return _storage.write(
      key: _key(userId, 'diet_logs'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<Food>> getFoods(String userId) async {
    final data = await _storage.read(key: _key(userId, 'foods'));
    if (data == null) return _defaultFoods();
    return (jsonDecode(data) as List)
        .map((e) => Food.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFood(String userId, Food food) async {
    await _withMutationLock(_key(userId, 'foods'), () async {
      final foods = await getFoods(userId);
      foods.add(food);
      await _writeFoods(userId, foods);
    });
  }

  Future<void> _writeFoods(String userId, List<Food> foods) {
    return _storage.write(
      key: _key(userId, 'foods'),
      value: jsonEncode(foods.map((f) => f.toJson()).toList()),
    );
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final data = await _storage.read(key: _key(userId, 'profile'));
    if (data == null) return null;
    return UserProfile.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  Future<void> saveUserProfile(String userId, UserProfile profile) async {
    await _storage.write(
      key: _key(userId, 'profile'),
      value: jsonEncode(profile.toJson()),
    );
  }

  Future<bool> getSubscriptionStatus(String userId) async {
    final data = await _storage.read(key: _key(userId, 'is_pro'));
    return data == 'true';
  }

  Future<void> setSubscriptionStatus(String userId, bool isPro) async {
    await _storage.write(key: _key(userId, 'is_pro'), value: isPro.toString());
  }

  // ---- Sync ----

  String _trainingSyncRecoveryKey(String userId, TrainingSyncDomain domain) =>
      _key(userId, '$_trainingSyncRecoveryType:${domain.wireName}');

  Future<void> _writeTrainingSyncMetadata(String key, String value) async {
    await _beforeTrainingSyncMetadataWrite?.call(key);
    await _storage.write(key: key, value: value);
  }

  Future<void> _deleteTrainingSyncMetadata(String key) async {
    await _beforeTrainingSyncMetadataWrite?.call(key);
    await _storage.delete(key: key);
  }

  Future<Set<String>> _getTrainingSyncRecoveryIds(
    String userId,
    TrainingSyncDomain domain,
  ) async {
    _validateUserId(userId);
    final raw = await _storage.read(
      key: _trainingSyncRecoveryKey(userId, domain),
    );
    if (raw == null) return <String>{};

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CorruptStorageDataException(
        'Stored training sync recovery data is not valid JSON.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _storageSchemaVersion ||
        decoded['userId'] != userId ||
        decoded['domain'] != domain.wireName ||
        decoded['entityIds'] is! List) {
      throw const CorruptStorageDataException(
        'Training sync recovery data has an invalid envelope.',
      );
    }

    final ids = <String>{};
    for (final value in decoded['entityIds'] as List) {
      if (value is! String || value.isEmpty || !ids.add(value)) {
        throw const CorruptStorageDataException(
          'Training sync recovery data contains invalid entity ids.',
        );
      }
    }
    return ids;
  }

  Future<void> _stageTrainingSyncRecovery(
    String userId,
    TrainingSyncDomain domain,
    Iterable<String> entityIds,
  ) async {
    final additions = entityIds.toSet();
    if (additions.isEmpty) return;
    if (!trainingSyncEnabled &&
        !await _readTrainingSyncBootstrapMarker(userId)) {
      return;
    }
    if (additions.any((id) => id.isEmpty)) {
      throw ArgumentError('Training sync recovery ids must not be empty.');
    }
    final ids = await _getTrainingSyncRecoveryIds(userId, domain)
      ..addAll(additions);
    final sortedIds = ids.toList()..sort();
    await _writeTrainingSyncMetadata(
      _trainingSyncRecoveryKey(userId, domain),
      jsonEncode({
        'schemaVersion': _storageSchemaVersion,
        'userId': userId,
        'domain': domain.wireName,
        'entityIds': sortedIds,
      }),
    );
  }

  Future<void> _clearTrainingSyncRecovery(
    String userId,
    TrainingSyncDomain domain,
    Iterable<String> entityIds,
  ) async {
    final removals = entityIds.toSet();
    if (removals.isEmpty) return;
    final ids = await _getTrainingSyncRecoveryIds(userId, domain)
      ..removeAll(removals);
    final key = _trainingSyncRecoveryKey(userId, domain);
    if (ids.isEmpty) {
      await _deleteTrainingSyncMetadata(key);
      return;
    }
    final sortedIds = ids.toList()..sort();
    await _writeTrainingSyncMetadata(
      key,
      jsonEncode({
        'schemaVersion': _storageSchemaVersion,
        'userId': userId,
        'domain': domain.wireName,
        'entityIds': sortedIds,
      }),
    );
  }

  Future<void> _preflightTrainingSyncOutbox(String userId) async {
    if (!trainingSyncEnabled) return;
    await getTrainingSyncOutbox(userId);
  }

  Future<List<TrainingSyncMutation>> getTrainingSyncOutbox(
    String userId,
  ) async {
    _validateUserId(userId);
    if (!trainingSyncEnabled) return [];
    final raw = await _storage.read(key: _key(userId, _trainingSyncOutboxType));
    if (raw == null) return [];

    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const CorruptStorageDataException(
        'Stored training sync outbox is not valid JSON.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CorruptStorageDataException(
        'Training sync outbox must contain a versioned object.',
      );
    }
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int) {
      throw const CorruptStorageDataException(
        'Training sync outbox has an invalid schema version.',
      );
    }
    if (schemaVersion != _storageSchemaVersion) {
      throw UnsupportedStorageVersionException(
        schemaVersion,
        'training sync outbox',
      );
    }
    if (decoded['userId'] != userId || decoded['data'] is! List) {
      throw const CorruptStorageDataException(
        'Training sync outbox has invalid owner or data.',
      );
    }

    final mutations = <TrainingSyncMutation>[];
    final compactKeys = <String>{};
    for (final item in decoded['data'] as List) {
      if (item is! Map) {
        throw const CorruptStorageDataException(
          'Training sync outbox contains an invalid item.',
        );
      }
      final TrainingSyncMutation mutation;
      try {
        mutation = TrainingSyncMutation.fromJson(
          Map<String, dynamic>.from(item),
          expectedUserId: userId,
        );
      } catch (_) {
        throw const CorruptStorageDataException(
          'Training sync outbox contains an invalid item.',
        );
      }
      if (!compactKeys.add(mutation.compactKey)) {
        throw const CorruptStorageDataException(
          'Training sync outbox contains duplicate entities.',
        );
      }
      mutations.add(mutation);
    }
    return mutations;
  }

  Future<void> _writeTrainingSyncOutbox(
    String userId,
    List<TrainingSyncMutation> mutations,
  ) async {
    _validateUserId(userId);
    if (!trainingSyncEnabled) return;
    final compactKeys = <String>{};
    for (final mutation in mutations) {
      if (mutation.userId != userId || !compactKeys.add(mutation.compactKey)) {
        throw ArgumentError(
          'Training sync outbox items must be owned and unique.',
        );
      }
    }
    await _writeTrainingSyncMetadata(
      _key(userId, _trainingSyncOutboxType),
      jsonEncode({
        'schemaVersion': _storageSchemaVersion,
        'userId': userId,
        'data': mutations.map((mutation) => mutation.toJson()).toList(),
      }),
    );
  }

  TrainingSyncMutation _trainingSyncMutation({
    required String userId,
    required TrainingSyncDomain domain,
    required String entityId,
    required TrainingSyncOperation operation,
    required Map<String, dynamic>? payload,
  }) {
    _validateUserId(userId);
    if (entityId.isEmpty) {
      throw ArgumentError('A non-empty training sync entity id is required.');
    }
    return TrainingSyncMutation.fromJson({
      'userId': userId,
      'domain': domain.wireName,
      'entityId': entityId,
      'operation': operation.wireName,
      'payload': payload,
      'token': _uuid.v4(),
    }, expectedUserId: userId);
  }

  Future<void> _enqueueTrainingSyncUpsert(
    String userId,
    TrainingSyncDomain domain,
    String entityId,
    Map<String, dynamic> payload,
  ) async {
    if (!trainingSyncEnabled) return;
    if (domain == TrainingSyncDomain.workout &&
        !_uuidPattern.hasMatch(entityId)) {
      await _clearTrainingSyncRecovery(userId, domain, [entityId]);
      return;
    }
    if (domain == TrainingSyncDomain.setLog &&
        !_isRemotelySyncableSetLog(WorkoutSetLog.fromJson(payload))) {
      await _clearTrainingSyncRecovery(userId, domain, [entityId]);
      return;
    }
    await _enqueueTrainingSyncMutations(userId, [
      _trainingSyncMutation(
        userId: userId,
        domain: domain,
        entityId: entityId,
        operation: TrainingSyncOperation.upsert,
        payload: payload,
      ),
    ]);
    await _clearTrainingSyncRecovery(userId, domain, [entityId]);
  }

  Future<void> _enqueueTrainingSyncDelete(
    String userId,
    TrainingSyncDomain domain,
    String entityId,
  ) async {
    if (!trainingSyncEnabled) return;
    if (domain == TrainingSyncDomain.workout &&
        !_uuidPattern.hasMatch(entityId)) {
      await _clearTrainingSyncRecovery(userId, domain, [entityId]);
      return;
    }
    await _enqueueTrainingSyncMutations(userId, [
      _trainingSyncMutation(
        userId: userId,
        domain: domain,
        entityId: entityId,
        operation: TrainingSyncOperation.delete,
        payload: null,
      ),
    ]);
    await _clearTrainingSyncRecovery(userId, domain, [entityId]);
  }

  Future<void> _enqueueTrainingSyncMutations(
    String userId,
    List<TrainingSyncMutation> candidates, {
    bool onlyIfAbsent = false,
  }) async {
    if (!trainingSyncEnabled || candidates.isEmpty) return;
    final outboxKey = _key(userId, _trainingSyncOutboxType);
    await _withMutationLock(outboxKey, () async {
      final mutations = await getTrainingSyncOutbox(userId);
      final byKey = {
        for (final mutation in mutations) mutation.compactKey: mutation,
      };
      for (final candidate in candidates) {
        if (!onlyIfAbsent || !byKey.containsKey(candidate.compactKey)) {
          byKey[candidate.compactKey] = candidate;
        }
      }
      await _writeTrainingSyncOutbox(userId, byKey.values.toList());
    });
  }

  Set<String> _trainingProgramMutationIds(
    List<TrainingProgram> previous,
    List<TrainingProgram> current,
  ) {
    final previousById = {for (final program in previous) program.id: program};
    final currentById = {for (final program in current) program.id: program};
    return {
      for (final id in {...previousById.keys, ...currentById.keys})
        if (jsonEncode(previousById[id]?.toJson()) !=
            jsonEncode(currentById[id]?.toJson()))
          id,
    };
  }

  Future<void> _enqueueTrainingProgramSnapshot(
    String userId,
    List<TrainingProgram> previous,
    List<TrainingProgram> current,
  ) async {
    if (!trainingSyncEnabled) return;
    final previousById = {for (final program in previous) program.id: program};
    final currentIds = current.map((program) => program.id).toSet();
    final mutations = <TrainingSyncMutation>[
      for (final program in current)
        if (jsonEncode(previousById[program.id]?.toJson()) !=
            jsonEncode(program.toJson()))
          _trainingSyncMutation(
            userId: userId,
            domain: TrainingSyncDomain.program,
            entityId: program.id,
            operation: TrainingSyncOperation.upsert,
            payload: program.toJson(),
          ),
      for (final program in previous)
        if (!currentIds.contains(program.id))
          _trainingSyncMutation(
            userId: userId,
            domain: TrainingSyncDomain.program,
            entityId: program.id,
            operation: TrainingSyncOperation.delete,
            payload: null,
          ),
    ];
    await _enqueueTrainingSyncMutations(userId, mutations);
    await _clearTrainingSyncRecovery(
      userId,
      TrainingSyncDomain.program,
      mutations.map((mutation) => mutation.entityId),
    );
  }

  Future<void> acknowledgeTrainingSyncMutation(
    String userId, {
    required TrainingSyncDomain domain,
    required String entityId,
    required String token,
  }) async {
    _validateUserId(userId);
    if (!trainingSyncEnabled) return;
    final outboxKey = _key(userId, _trainingSyncOutboxType);
    await _withMutationLock(outboxKey, () async {
      final mutations = await getTrainingSyncOutbox(userId);
      mutations.removeWhere(
        (mutation) =>
            mutation.domain == domain &&
            mutation.entityId == entityId &&
            mutation.token == token,
      );
      await _writeTrainingSyncOutbox(userId, mutations);
    });
  }

  Future<bool> isTrainingSyncBootstrapped(String userId) async {
    _validateUserId(userId);
    if (!trainingSyncEnabled) return false;
    return _readTrainingSyncBootstrapMarker(userId);
  }

  Future<bool> _readTrainingSyncBootstrapMarker(String userId) async {
    _validateUserId(userId);
    final value = await _storage.read(
      key: _key(userId, _trainingSyncBootstrapType),
    );
    if (value == null) return false;
    if (value != 'true') {
      throw const CorruptStorageDataException(
        'Training sync bootstrap marker is invalid.',
      );
    }
    return true;
  }

  Future<void> bootstrapTrainingSyncOutbox(String userId) async {
    if (!trainingSyncEnabled) return;
    final bootstrapped = await isTrainingSyncBootstrapped(userId);
    for (final domain in TrainingSyncDomain.values) {
      await _bootstrapTrainingSyncDomain(
        userId,
        domain,
        includeBaseline: !bootstrapped,
      );
    }
    if (!bootstrapped) {
      await _writeTrainingSyncMetadata(
        _key(userId, _trainingSyncBootstrapType),
        'true',
      );
    }
  }

  Future<void> _bootstrapTrainingSyncDomain(
    String userId,
    TrainingSyncDomain domain, {
    required bool includeBaseline,
  }) async {
    final storageType = switch (domain) {
      TrainingSyncDomain.program => _trainingProgramsType,
      TrainingSyncDomain.rule => _progressionRulesType,
      TrainingSyncDomain.workout => _workoutLogsType,
      TrainingSyncDomain.setLog => _workoutSetLogsType,
    };
    await _withMutationLock(_key(userId, storageType), () async {
      final recoveryIds = await _getTrainingSyncRecoveryIds(userId, domain);
      if (!includeBaseline && recoveryIds.isEmpty) return;

      final baseline = <TrainingSyncMutation>[];
      final recovered = <TrainingSyncMutation>[];
      switch (domain) {
        case TrainingSyncDomain.program:
          final items = await getTrainingPrograms(userId);
          final byId = {for (final item in items) item.id: item};
          if (includeBaseline) {
            baseline.addAll(
              items.map(
                (item) => _trainingSyncMutation(
                  userId: userId,
                  domain: domain,
                  entityId: item.id,
                  operation: TrainingSyncOperation.upsert,
                  payload: item.toJson(),
                ),
              ),
            );
          }
          for (final id in recoveryIds) {
            final item = byId[id];
            recovered.add(
              _trainingSyncMutation(
                userId: userId,
                domain: domain,
                entityId: id,
                operation: item == null
                    ? TrainingSyncOperation.delete
                    : TrainingSyncOperation.upsert,
                payload: item?.toJson(),
              ),
            );
          }
        case TrainingSyncDomain.rule:
          final items = await getProgressionRules(userId);
          final byId = {for (final item in items) item.id: item};
          if (includeBaseline) {
            baseline.addAll(
              items.map(
                (item) => _trainingSyncMutation(
                  userId: userId,
                  domain: domain,
                  entityId: item.id,
                  operation: TrainingSyncOperation.upsert,
                  payload: item.toJson(),
                ),
              ),
            );
          }
          for (final id in recoveryIds) {
            final item = byId[id];
            recovered.add(
              _trainingSyncMutation(
                userId: userId,
                domain: domain,
                entityId: id,
                operation: item == null
                    ? TrainingSyncOperation.delete
                    : TrainingSyncOperation.upsert,
                payload: item?.toJson(),
              ),
            );
          }
        case TrainingSyncDomain.workout:
          final items = await _getAllWorkoutLogs(userId);
          final byId = {for (final item in items) item.id: item};
          if (includeBaseline) {
            baseline.addAll(
              items
                  .where((item) => _uuidPattern.hasMatch(item.id))
                  .map(
                    (item) => _trainingSyncMutation(
                      userId: userId,
                      domain: domain,
                      entityId: item.id,
                      operation: TrainingSyncOperation.upsert,
                      payload: item.toJson(),
                    ),
                  ),
            );
          }
          for (final id in recoveryIds.where(_uuidPattern.hasMatch)) {
            final item = byId[id];
            recovered.add(
              _trainingSyncMutation(
                userId: userId,
                domain: domain,
                entityId: id,
                operation: item == null
                    ? TrainingSyncOperation.delete
                    : TrainingSyncOperation.upsert,
                payload: item?.toJson(),
              ),
            );
          }
        case TrainingSyncDomain.setLog:
          final items = await _getAllWorkoutSetLogs(userId);
          final byId = {for (final item in items) item.id: item};
          final workoutIds = (await _getAllWorkoutLogs(
            userId,
          )).map((item) => item.id).toSet();
          TrainingSyncMutation? mutationFor(WorkoutSetLog item) {
            if (!_isRemotelySyncableSetLog(item)) return null;
            final parentExists = workoutIds.contains(item.workoutLogId);
            return _trainingSyncMutation(
              userId: userId,
              domain: domain,
              entityId: item.id,
              operation: parentExists
                  ? TrainingSyncOperation.upsert
                  : TrainingSyncOperation.delete,
              payload: parentExists ? item.toJson() : null,
            );
          }

          if (includeBaseline) {
            baseline.addAll(items.map(mutationFor).nonNulls);
          }
          for (final id in recoveryIds) {
            final item = byId[id];
            if (item == null) {
              recovered.add(
                _trainingSyncMutation(
                  userId: userId,
                  domain: domain,
                  entityId: id,
                  operation: TrainingSyncOperation.delete,
                  payload: null,
                ),
              );
              continue;
            }
            final mutation = mutationFor(item);
            recovered.add(
              mutation ??
                  _trainingSyncMutation(
                    userId: userId,
                    domain: domain,
                    entityId: id,
                    operation: TrainingSyncOperation.delete,
                    payload: null,
                  ),
            );
          }
      }

      await _enqueueTrainingSyncMutations(userId, baseline, onlyIfAbsent: true);
      await _enqueueTrainingSyncMutations(userId, recovered);
      await _clearTrainingSyncRecovery(userId, domain, recoveryIds);
    });
  }

  Future<List<WorkoutLog>> getAllWorkoutLogsForSync(String userId) =>
      _getAllWorkoutLogs(userId);

  Future<List<WorkoutSetLog>> getAllWorkoutSetLogsForSync(String userId) =>
      _getAllWorkoutSetLogs(userId);

  Future<bool> _hasPendingTrainingDomain(
    String userId,
    TrainingSyncDomain domain,
  ) async {
    if ((await _getTrainingSyncRecoveryIds(userId, domain)).isNotEmpty) {
      return true;
    }
    return (await getTrainingSyncOutbox(
      userId,
    )).any((mutation) => mutation.domain == domain);
  }

  Future<bool> replaceTrainingProgramsFromSyncIfNoPending(
    String userId,
    List<TrainingProgram> programs,
  ) async {
    _validateTrainingProgramWrite(userId, programs);
    final snapshot = List<TrainingProgram>.of(programs);
    return _withMutationLock(_key(userId, _trainingProgramsType), () async {
      await getTrainingPrograms(userId);
      if (await _hasPendingTrainingDomain(userId, TrainingSyncDomain.program)) {
        return false;
      }
      await _writeTrainingProgramsV1(userId, snapshot);
      return true;
    });
  }

  Future<bool> replaceProgressionRulesFromSyncIfNoPending(
    String userId,
    List<ProgressionRule> rules,
  ) async {
    _validateProgressionRuleWrite(userId, rules);
    final snapshot = List<ProgressionRule>.of(rules);
    return _withMutationLock(_key(userId, _progressionRulesType), () async {
      await getProgressionRules(userId);
      if (await _hasPendingTrainingDomain(userId, TrainingSyncDomain.rule)) {
        return false;
      }
      await _writeProgressionRulesV1(userId, snapshot);
      return true;
    });
  }

  Future<bool> replaceWorkoutLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutLog> logs,
  ) async {
    _validateWorkoutLogWrite(userId, logs);
    final snapshot = List<WorkoutLog>.of(logs);
    return _withMutationLock(_key(userId, _workoutLogsType), () async {
      final existing = await _getAllWorkoutLogs(userId);
      if (await _hasPendingTrainingDomain(userId, TrainingSyncDomain.workout)) {
        return false;
      }
      final localOnly = existing.where((log) => !_uuidPattern.hasMatch(log.id));
      await _writeWorkoutLogsV1(userId, [...snapshot, ...localOnly]);
      return true;
    });
  }

  Future<bool> replaceWorkoutSetLogsFromSyncIfNoPending(
    String userId,
    List<WorkoutSetLog> logs,
  ) async {
    _validateWorkoutSetLogWrite(userId, logs);
    if (logs.any((log) => !_isRemotelySyncableSetLog(log))) {
      throw ArgumentError('Remote workout set logs require a complete slot.');
    }
    final snapshot = List<WorkoutSetLog>.of(logs);
    return _withWorkoutAndSetMutationLocks(userId, () async {
      final existing = await _getAllWorkoutSetLogs(userId);
      if (await _hasPendingTrainingDomain(userId, TrainingSyncDomain.setLog)) {
        return false;
      }
      final workoutIds = (await _getAllWorkoutLogs(
        userId,
      )).map((workout) => workout.id).toSet();
      final missingParent = snapshot
          .where((log) => !workoutIds.contains(log.workoutLogId))
          .firstOrNull;
      if (missingParent != null) {
        throw StateError(
          'Remote workout set ${missingParent.id} requires an existing '
          'workout log.',
        );
      }
      final localOnly = existing.where(
        (log) => !_isRemotelySyncableSetLog(log),
      );
      await _writeWorkoutSetLogsV1(userId, [...snapshot, ...localOnly]);
      return true;
    });
  }

  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs) async {
    _validateWorkoutLogWrite(userId, logs);
    final snapshot = List<WorkoutLog>.of(logs);
    final storageKey = _key(userId, _workoutLogsType);
    await _withMutationLock(storageKey, () async {
      final existing = await _getAllWorkoutLogs(userId);
      final existingIds = existing.map((log) => log.id).toSet();
      for (final log in snapshot) {
        if (existingIds.add(log.id)) {
          existing.add(log);
        }
      }
      await _writeWorkoutLogsV1(userId, existing);
    });
  }

  Future<void> saveDietLogs(String userId, List<DietLog> logs) async {
    final snapshot = List<DietLog>.of(logs);
    await _withMutationLock(_key(userId, 'diet_logs'), () async {
      final existing = await _getAllDietLogs(userId);
      final existingIds = existing.map((log) => log.id).toSet();
      for (final log in snapshot) {
        if (!existingIds.contains(log.id)) {
          existing.add(log);
        }
      }
      await _writeDietLogs(userId, existing);
    });
  }

  Future<List<WorkoutLog>> getUnsyncedWorkoutLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'unsynced_workouts'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addUnsyncedWorkout(String userId, WorkoutLog log) async {
    await _withMutationLock(_key(userId, 'unsynced_workouts'), () async {
      final unsynced = await getUnsyncedWorkoutLogs(userId);
      unsynced.add(log);
      await _writeUnsyncedWorkoutLogs(userId, unsynced);
    });
  }

  Future<void> _writeUnsyncedWorkoutLogs(String userId, List<WorkoutLog> logs) {
    return _storage.write(
      key: _key(userId, 'unsynced_workouts'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearUnsyncedWorkouts(String userId) async {
    final storageKey = _key(userId, 'unsynced_workouts');
    await _withMutationLock(storageKey, () async {
      await _storage.delete(key: storageKey);
    });
  }

  Future<void> removeUnsyncedWorkoutLogs(String userId, Set<String> ids) async {
    if (ids.isEmpty) return;
    await _withMutationLock(_key(userId, 'unsynced_workouts'), () async {
      final unsynced = await getUnsyncedWorkoutLogs(userId);
      unsynced.removeWhere((log) => ids.contains(log.id));
      await _writeUnsyncedWorkoutLogs(userId, unsynced);
    });
  }

  Future<List<DietLog>> getUnsyncedDietLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'unsynced_diets'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addUnsyncedDiet(String userId, DietLog log) async {
    await _withMutationLock(_key(userId, 'unsynced_diets'), () async {
      final unsynced = await getUnsyncedDietLogs(userId);
      final index = unsynced.indexWhere((item) => item.id == log.id);
      if (index >= 0) {
        unsynced[index] = log;
      } else {
        unsynced.add(log);
      }
      await _writeUnsyncedDietLogs(userId, unsynced);
    });
  }

  Future<void> _writeUnsyncedDietLogs(String userId, List<DietLog> logs) {
    return _storage.write(
      key: _key(userId, 'unsynced_diets'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeUnsyncedDietLogs(String userId, Set<String> ids) async {
    if (ids.isEmpty) return;
    await _withMutationLock(_key(userId, 'unsynced_diets'), () async {
      final unsynced = await getUnsyncedDietLogs(userId);
      unsynced.removeWhere((log) => ids.contains(log.id));
      await _writeUnsyncedDietLogs(userId, unsynced);
    });
  }

  Future<List<String>> getPendingWorkoutDeletes(String userId) =>
      _getStringList(userId, 'pending_workout_deletes');

  Future<void> addPendingWorkoutDelete(String userId, String id) =>
      _addString(userId, 'pending_workout_deletes', id);

  Future<void> removePendingWorkoutDeletes(String userId, Set<String> ids) =>
      _removeStrings(userId, 'pending_workout_deletes', ids);

  Future<List<String>> getPendingDietDeletes(String userId) =>
      _getStringList(userId, 'pending_diet_deletes');

  Future<void> addPendingDietDelete(String userId, String id) =>
      _addString(userId, 'pending_diet_deletes', id);

  Future<void> removePendingDietDeletes(String userId, Set<String> ids) =>
      _removeStrings(userId, 'pending_diet_deletes', ids);

  Future<String?> getLastSyncTime(String userId) async {
    return _storage.read(key: _key(userId, 'last_sync'));
  }

  Future<void> setLastSyncTime(String userId) async {
    await _storage.write(
      key: _key(userId, 'last_sync'),
      value: DateTime.now().toIso8601String(),
    );
  }

  // ---- Templates ----
  Future<List<WorkoutTemplate>> getTemplates(String userId) async {
    final data = await _storage.read(key: _key(userId, 'templates'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutTemplate.fromJson(e))
        .toList();
  }

  Future<void> saveTemplate(String userId, WorkoutTemplate template) async {
    await _withMutationLock(_key(userId, 'templates'), () async {
      final templates = await getTemplates(userId);
      templates.add(template);
      await _writeTemplates(userId, templates);
    });
  }

  Future<void> _writeTemplates(String userId, List<WorkoutTemplate> templates) {
    return _storage.write(
      key: _key(userId, 'templates'),
      value: jsonEncode(
        templates.map((template) => template.toJson()).toList(),
      ),
    );
  }

  Future<void> deleteTemplate(String userId, String templateId) async {
    await _withMutationLock(_key(userId, 'templates'), () async {
      final templates = await getTemplates(userId);
      templates.removeWhere((template) => template.id == templateId);
      await _writeTemplates(userId, templates);
    });
  }

  // ---- Meal Templates ----
  Future<List<String>> getMealTemplates(String userId) async {
    final data = await _storage.read(key: _key(userId, 'meal_templates'));
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e['name'] as String).toList();
  }

  Future<void> saveMealTemplate(String userId, String name, String data) async {
    await _withMutationLock(_key(userId, 'meal_templates'), () async {
      final templates = await _storage.read(
        key: _key(userId, 'meal_templates'),
      );
      final list = templates != null ? (jsonDecode(templates) as List) : [];
      list.add({'name': name, 'data': data});
      await _storage.write(
        key: _key(userId, 'meal_templates'),
        value: jsonEncode(list),
      );
    });
  }

  Future<String?> getMealTemplateData(String userId, String name) async {
    final data = await _storage.read(key: _key(userId, 'meal_templates'));
    if (data == null) return null;
    final list = jsonDecode(data) as List;
    for (final item in list) {
      if (item['name'] == name) return item['data'] as String;
    }
    return null;
  }

  // ---- Nutrition Plan ----
  Future<Map<String, dynamic>?> getNutritionPlan(String userId) async {
    final data = await _storage.read(key: _key(userId, 'nutrition_plan'));
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    if (decoded.isEmpty) return null;
    return decoded;
  }

  Future<void> saveNutritionPlan(
    String userId,
    Map<String, dynamic> plan,
  ) async {
    await _storage.write(
      key: _key(userId, 'nutrition_plan'),
      value: jsonEncode(plan),
    );
  }

  Future<void> deleteNutritionPlan(String userId) async {
    await _storage.delete(key: _key(userId, 'nutrition_plan'));
  }

  // ---- Body Measurements ----
  Future<List<BodyMeasurement>> getBodyMeasurements(String userId) async {
    final data = await _storage.read(key: _key(userId, 'body_measurements'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBodyMeasurement(String userId, BodyMeasurement entry) async {
    await _withMutationLock(_key(userId, 'body_measurements'), () async {
      final entries = await getBodyMeasurements(userId);
      entries.insert(0, entry);
      await _writeBodyMeasurements(userId, entries);
    });
  }

  Future<void> _writeBodyMeasurements(
    String userId,
    List<BodyMeasurement> entries,
  ) {
    return _storage.write(
      key: _key(userId, 'body_measurements'),
      value: jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteBodyMeasurement(String userId, String id) async {
    await _withMutationLock(_key(userId, 'body_measurements'), () async {
      final entries = await getBodyMeasurements(userId);
      entries.removeWhere((entry) => entry.id == id);
      await _writeBodyMeasurements(userId, entries);
    });
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  Future<List<String>> _getStringList(String userId, String type) async {
    final data = await _storage.read(key: _key(userId, type));
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e.toString()).toList();
  }

  Future<void> _saveStringList(
    String userId,
    String type,
    List<String> values,
  ) async {
    await _storage.write(key: _key(userId, type), value: jsonEncode(values));
  }

  Future<void> _addString(String userId, String type, String value) async {
    await _withMutationLock(_key(userId, type), () async {
      final values = await _getStringList(userId, type);
      if (!values.contains(value)) values.add(value);
      await _saveStringList(userId, type, values);
    });
  }

  Future<void> _removeStrings(
    String userId,
    String type,
    Set<String> valuesToRemove,
  ) async {
    if (valuesToRemove.isEmpty) return;
    await _withMutationLock(_key(userId, type), () async {
      final values = await _getStringList(userId, type);
      values.removeWhere(valuesToRemove.contains);
      await _saveStringList(userId, type, values);
    });
  }

  List<Food> _defaultFoods() => [
    Food(
      id: 'food_chicken',
      name: '鸡胸肉',
      caloriesPer100g: 133,
      proteinPer100g: 31,
      carbsPer100g: 0,
      fatPer100g: 1.2,
    ),
    Food(
      id: 'food_egg',
      name: '鸡蛋',
      caloriesPer100g: 155,
      proteinPer100g: 13,
      carbsPer100g: 1.1,
      fatPer100g: 11,
    ),
    Food(
      id: 'food_rice',
      name: '白米饭',
      caloriesPer100g: 116,
      proteinPer100g: 2.6,
      carbsPer100g: 25.9,
      fatPer100g: 0.3,
    ),
    Food(
      id: 'food_sweetpotato',
      name: '红薯',
      caloriesPer100g: 86,
      proteinPer100g: 1.6,
      carbsPer100g: 20.1,
      fatPer100g: 0.1,
    ),
    Food(
      id: 'food_salmon',
      name: '三文鱼',
      caloriesPer100g: 208,
      proteinPer100g: 20,
      carbsPer100g: 0,
      fatPer100g: 13,
    ),
    Food(
      id: 'food_beef',
      name: '牛肉',
      caloriesPer100g: 250,
      proteinPer100g: 26,
      carbsPer100g: 0,
      fatPer100g: 15,
    ),
    Food(
      id: 'food_broccoli',
      name: '西兰花',
      caloriesPer100g: 34,
      proteinPer100g: 2.8,
      carbsPer100g: 7,
      fatPer100g: 0.4,
    ),
    Food(
      id: 'food_oatmeal',
      name: '燕麦',
      caloriesPer100g: 367,
      proteinPer100g: 13.5,
      carbsPer100g: 66,
      fatPer100g: 6.5,
    ),
    Food(
      id: 'food_milk',
      name: '全脂牛奶',
      caloriesPer100g: 61,
      proteinPer100g: 3.2,
      carbsPer100g: 4.8,
      fatPer100g: 3.2,
    ),
    Food(
      id: 'food_banana',
      name: '香蕉',
      caloriesPer100g: 89,
      proteinPer100g: 1.1,
      carbsPer100g: 23,
      fatPer100g: 0.3,
    ),
    Food(
      id: 'food_protein_shake',
      name: '蛋白粉(乳清)',
      caloriesPer100g: 380,
      proteinPer100g: 75,
      carbsPer100g: 10,
      fatPer100g: 5,
    ),
    Food(
      id: 'food_bread',
      name: '全麦面包',
      caloriesPer100g: 247,
      proteinPer100g: 13,
      carbsPer100g: 41,
      fatPer100g: 3.4,
    ),
  ];
}
