import 'dart:convert';

import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _storage = FlutterSecureStorage();

String _key(String userId, String type) => '$userId:$type';

String _v1(List<Map<String, dynamic>> data) =>
    jsonEncode({'schemaVersion': 1, 'data': data});

Future<String?> _raw(String userId, String type) =>
    _storage.read(key: _key(userId, type));

Map<String, dynamic> _envelope(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

List<Map<String, dynamic>> _envelopeData(String raw) =>
    (_envelope(raw)['data'] as List<dynamic>).cast<Map<String, dynamic>>();

WorkoutLog _workoutLog({
  required String userId,
  required String id,
  DateTime? date,
  String? programId,
  String? programDayId,
  String? programExerciseId,
}) => WorkoutLog(
  id: id,
  userId: userId,
  exerciseId: 'exercise-$id',
  programId: programId,
  programDayId: programDayId,
  programExerciseId: programExerciseId,
  date: date ?? DateTime.utc(2025, 1, 15),
  sets: 3,
  reps: 8,
  weightKg: 80,
  createdAt: DateTime.utc(2025, 1, 15, 8),
);

WorkoutSetLog _setLog({
  required String id,
  String? workoutLogId,
  String? programId,
  String? programDayId,
  String? programExerciseId,
}) => WorkoutSetLog(
  id: id,
  workoutLogId: workoutLogId ?? 'workout-$id',
  programId: programId ?? 'program-$id',
  programDayId: programDayId,
  programExerciseId: programExerciseId ?? 'program-exercise-$id',
  setIndex: 0,
  reps: 8,
  weightKg: 80,
  completed: true,
);

ProgressionRule _rule({
  required String userId,
  required String id,
  String? exerciseId,
}) => ProgressionRule(
  id: id,
  userId: userId,
  exerciseId: exerciseId ?? 'exercise-$id',
  type: ProgressionType.doubleProgression,
  increment: 2.5,
  targetSets: 3,
  targetReps: 8,
);

TrainingProgram _program({required String userId, required String id}) {
  final timestamp = DateTime.utc(2025, 1, 15);
  return TrainingProgram(
    id: id,
    userId: userId,
    name: 'Program $id',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<Object?> _capture(Future<void> operation) async {
  try {
    await operation;
    return null;
  } catch (error) {
    return error;
  }
}

Matcher _storageError({required bool corrupt, required String blobLabel}) {
  if (corrupt) {
    return isA<CorruptStorageDataException>().having(
      (error) => error.message,
      'message',
      contains(blobLabel),
    );
  }
  return isA<UnsupportedStorageVersionException>().having(
    (error) => error.blobType,
    'blobType',
    blobLabel,
  );
}

void main() {
  final database = AppDatabase.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('workout log storage v1', () {
    test(
      'legacy read is non-mutating and add upgrades without data loss',
      () async {
        const userId = 'workout-legacy-owner';
        final legacy = _workoutLog(
          userId: userId,
          id: 'legacy',
          programId: 'program',
          programDayId: 'day',
          programExerciseId: 'slot',
        );
        final legacyRaw = jsonEncode([legacy.toJson()]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'workout_logs'): legacyRaw,
        });

        final read = await database.getWorkoutLogs(
          userId,
          DateTime.utc(2025, 1, 15),
        );

        expect(read.single.id, 'legacy');
        expect(read.single.programDayId, 'day');
        expect(await _raw(userId, 'workout_logs'), legacyRaw);

        await database.addWorkoutLog(
          userId,
          _workoutLog(userId: userId, id: 'added'),
        );

        final upgraded = (await _raw(userId, 'workout_logs'))!;
        expect(_envelope(upgraded)['schemaVersion'], 1);
        expect(
          _envelopeData(upgraded).map((item) => item['id']),
          unorderedEquals(['legacy', 'added']),
        );
        expect(
          (await database.getWorkoutLogsForMonth(
            userId,
            DateTime.utc(2025, 1),
          )).map((log) => log.id),
          unorderedEquals(['legacy', 'added']),
        );
      },
    );

    test('v1 read preserves program slot fields', () async {
      const userId = 'workout-v1-owner';
      final raw = _v1([
        _workoutLog(
          userId: userId,
          id: 'slot-log',
          programId: 'program',
          programDayId: 'day',
          programExerciseId: 'slot',
        ).toJson(),
      ]);
      FlutterSecureStorage.setMockInitialValues({
        _key(userId, 'workout_logs'): raw,
      });

      final result = await database.getWorkoutLogsForMonth(
        userId,
        DateTime.utc(2025, 1),
      );

      expect(result.single.hasProgramSlot, isTrue);
      expect(result.single.programDayId, 'day');
      expect(await _raw(userId, 'workout_logs'), raw);
    });

    for (final format in ['legacy', 'v1']) {
      test('$format owner mismatch fails closed', () async {
        const userId = 'workout-requested-owner';
        final foreign = _workoutLog(
          userId: 'workout-foreign-owner',
          id: 'foreign',
        ).toJson();
        final raw = format == 'legacy' ? jsonEncode([foreign]) : _v1([foreign]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'workout_logs'): raw,
        });

        await expectLater(
          database.getWorkoutLogsForMonth(userId, DateTime.utc(2025, 1)),
          throwsA(isA<CorruptStorageDataException>()),
        );
        expect(await _raw(userId, 'workout_logs'), raw);
      });
    }

    test(
      'partial stored program slot is corrupt and remains unchanged',
      () async {
        const userId = 'workout-partial-slot-owner';
        final item = _workoutLog(userId: userId, id: 'partial').toJson()
          ..['programId'] = 'program';
        final raw = jsonEncode([item]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'workout_logs'): raw,
        });

        await expectLater(
          database.getWorkoutLogsForMonth(userId, DateTime.utc(2025, 1)),
          throwsA(isA<CorruptStorageDataException>()),
        );
        expect(await _raw(userId, 'workout_logs'), raw);
      },
    );

    test('incoming owner and slot mismatches are rejected', () async {
      await expectLater(
        database.addWorkoutLog(
          'requested-owner',
          _workoutLog(userId: 'foreign-owner', id: 'foreign'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        database.saveWorkoutLogs('requested-owner', [
          _workoutLog(
            userId: 'requested-owner',
            id: 'empty-slot',
            programId: '',
            programDayId: 'day',
            programExerciseId: 'slot',
          ),
        ]),
        throwsA(isA<ArgumentError>()),
      );
      expect(await _raw('requested-owner', 'workout_logs'), isNull);
    });

    for (final corrupt in [false, true]) {
      test(
        '${corrupt ? 'corrupt' : 'future'} raw rejects concurrent add, bulk save, and delete',
        () async {
          const userId = 'workout-guarded-owner';
          final raw = corrupt
              ? '{not-workout-json'
              : jsonEncode({'schemaVersion': 7, 'data': <Object>[]});
          FlutterSecureStorage.setMockInitialValues({
            _key(userId, 'workout_logs'): raw,
          });

          final errors = await Future.wait([
            _capture(
              database.addWorkoutLog(
                userId,
                _workoutLog(userId: userId, id: 'add'),
              ),
            ),
            _capture(
              database.saveWorkoutLogs(userId, [
                _workoutLog(userId: userId, id: 'bulk'),
              ]),
            ),
            _capture(database.deleteWorkoutLog(userId, 'delete')),
          ]);

          expect(
            errors,
            everyElement(
              _storageError(corrupt: corrupt, blobLabel: 'workout log'),
            ),
          );
          expect(await _raw(userId, 'workout_logs'), raw);
        },
      );
    }

    test(
      'same-key concurrent add, bulk save, and delete lose no updates',
      () async {
        const userId = 'workout-concurrency-owner';
        await database.addWorkoutLog(
          userId,
          _workoutLog(userId: userId, id: 'delete-me'),
        );

        await Future.wait([
          database.deleteWorkoutLog(userId, 'delete-me'),
          ...List.generate(
            20,
            (index) => database.addWorkoutLog(
              userId,
              _workoutLog(userId: userId, id: 'add-$index'),
            ),
          ),
          ...List.generate(
            10,
            (index) => database.saveWorkoutLogs(userId, [
              _workoutLog(userId: userId, id: 'bulk-$index'),
            ]),
          ),
        ]);

        final logs = await database.getWorkoutLogsForMonth(
          userId,
          DateTime.utc(2025, 1),
        );
        expect(logs, hasLength(30));
        expect(logs.map((log) => log.id), isNot(contains('delete-me')));
        expect(logs.map((log) => log.id).toSet(), hasLength(30));
        expect(
          _envelope((await _raw(userId, 'workout_logs'))!)['schemaVersion'],
          1,
        );
      },
    );
  });

  group('workout set log storage v1', () {
    test(
      'legacy missing day slot reads unchanged and next save upgrades',
      () async {
        const userId = 'set-legacy-owner';
        final legacyRaw = jsonEncode([_setLog(id: 'legacy').toJson()]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'workout_set_logs'): legacyRaw,
        });

        final legacy = await database.getWorkoutSetLogs(
          userId,
          'workout-legacy',
        );

        expect(legacy.single.programDayId, isNull);
        expect(await _raw(userId, 'workout_set_logs'), legacyRaw);

        await database.saveWorkoutSetLogs(userId, [
          _setLog(id: 'new', programDayId: 'day-new'),
        ]);

        final upgraded = (await _raw(userId, 'workout_set_logs'))!;
        expect(_envelope(upgraded)['schemaVersion'], 1);
        expect(
          _envelopeData(upgraded).map((item) => item['id']),
          unorderedEquals(['legacy', 'new']),
        );
        final added = _envelopeData(
          upgraded,
        ).singleWhere((item) => item['id'] == 'new');
        expect(added['programDayId'], 'day-new');
      },
    );

    test('invalid stored and incoming slot structures fail closed', () async {
      const userId = 'set-invalid-owner';
      final invalidItem = _setLog(id: 'invalid').toJson()
        ..remove('programExerciseId');
      final raw = _v1([invalidItem]);
      FlutterSecureStorage.setMockInitialValues({
        _key(userId, 'workout_set_logs'): raw,
      });

      await expectLater(
        database.getWorkoutSetLogs(userId, 'workout-invalid'),
        throwsA(isA<CorruptStorageDataException>()),
      );
      await expectLater(
        database.saveWorkoutSetLogs(userId, [_setLog(id: 'replacement')]),
        throwsA(isA<CorruptStorageDataException>()),
      );
      expect(await _raw(userId, 'workout_set_logs'), raw);

      FlutterSecureStorage.setMockInitialValues({});
      await expectLater(
        database.saveWorkoutSetLogs(userId, [
          _setLog(id: 'empty-day', programDayId: ''),
        ]),
        throwsA(isA<ArgumentError>()),
      );
      expect(await _raw(userId, 'workout_set_logs'), isNull);
    });

    for (final corrupt in [false, true]) {
      test(
        '${corrupt ? 'corrupt' : 'future'} raw rejects save unchanged',
        () async {
          const userId = 'set-guarded-owner';
          final raw = corrupt
              ? jsonEncode({
                  'schemaVersion': 1,
                  'data': [42],
                })
              : jsonEncode({'schemaVersion': 3, 'data': <Object>[]});
          FlutterSecureStorage.setMockInitialValues({
            _key(userId, 'workout_set_logs'): raw,
          });

          await expectLater(
            database.saveWorkoutSetLogs(userId, [_setLog(id: 'new')]),
            throwsA(
              _storageError(corrupt: corrupt, blobLabel: 'workout set log'),
            ),
          );
          expect(await _raw(userId, 'workout_set_logs'), raw);
        },
      );
    }

    test('same-key concurrent saves retain every set log', () async {
      const userId = 'set-concurrency-owner';

      await Future.wait(
        List.generate(
          25,
          (index) => database.saveWorkoutSetLogs(userId, [
            _setLog(id: 'set-$index', workoutLogId: 'shared-workout'),
          ]),
        ),
      );

      final logs = await database.getWorkoutSetLogs(userId, 'shared-workout');
      expect(logs, hasLength(25));
      expect(logs.map((log) => log.id).toSet(), hasLength(25));
      expect(
        _envelope((await _raw(userId, 'workout_set_logs'))!)['schemaVersion'],
        1,
      );
    });
  });

  group('progression rule storage v1', () {
    test(
      'legacy read is non-mutating and save upgrades without data loss',
      () async {
        const userId = 'rule-legacy-owner';
        final legacyRaw = jsonEncode([
          _rule(userId: userId, id: 'legacy').toJson(),
        ]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'progression_rules'): legacyRaw,
        });

        expect(
          (await database.getProgressionRules(userId)).single.id,
          'legacy',
        );
        expect(await _raw(userId, 'progression_rules'), legacyRaw);

        await database.saveProgressionRule(
          userId,
          _rule(userId: userId, id: 'new'),
        );

        final upgraded = (await _raw(userId, 'progression_rules'))!;
        expect(_envelope(upgraded)['schemaVersion'], 1);
        expect(
          (await database.getProgressionRules(userId)).map((rule) => rule.id),
          unorderedEquals(['legacy', 'new']),
        );
      },
    );

    for (final format in ['legacy', 'v1']) {
      test('$format owner mismatch fails closed', () async {
        const userId = 'rule-requested-owner';
        final foreign = _rule(
          userId: 'rule-foreign-owner',
          id: 'foreign',
        ).toJson();
        final raw = format == 'legacy' ? jsonEncode([foreign]) : _v1([foreign]);
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'progression_rules'): raw,
        });

        await expectLater(
          database.getProgressionRules(userId),
          throwsA(isA<CorruptStorageDataException>()),
        );
        expect(await _raw(userId, 'progression_rules'), raw);
      });
    }

    test('incoming owner mismatch is rejected without a write', () async {
      await expectLater(
        database.saveProgressionRule(
          'requested-owner',
          _rule(userId: 'foreign-owner', id: 'foreign'),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await _raw('requested-owner', 'progression_rules'), isNull);
    });

    for (final corrupt in [false, true]) {
      test(
        '${corrupt ? 'corrupt' : 'future'} raw rejects concurrent save and delete',
        () async {
          const userId = 'rule-guarded-owner';
          final raw = corrupt
              ? jsonEncode({
                  'schemaVersion': 1,
                  'data': [42],
                })
              : jsonEncode({'schemaVersion': 4, 'data': <Object>[]});
          FlutterSecureStorage.setMockInitialValues({
            _key(userId, 'progression_rules'): raw,
          });

          final errors = await Future.wait([
            _capture(
              database.saveProgressionRule(
                userId,
                _rule(userId: userId, id: 'new'),
              ),
            ),
            _capture(database.deleteProgressionRule(userId, 'exercise-old')),
          ]);

          expect(
            errors,
            everyElement(
              _storageError(corrupt: corrupt, blobLabel: 'progression rule'),
            ),
          );
          expect(await _raw(userId, 'progression_rules'), raw);
        },
      );
    }

    test('same-key concurrent saves retain every distinct rule', () async {
      const userId = 'rule-concurrency-owner';

      await Future.wait(
        List.generate(
          25,
          (index) => database.saveProgressionRule(
            userId,
            _rule(userId: userId, id: 'rule-$index'),
          ),
        ),
      );

      final rules = await database.getProgressionRules(userId);
      expect(rules, hasLength(25));
      expect(rules.map((rule) => rule.id).toSet(), hasLength(25));
      expect(
        _envelope((await _raw(userId, 'progression_rules'))!)['schemaVersion'],
        1,
      );
    });
  });

  group('key isolation and mutation queue', () {
    test(
      'all protected writes reject an empty user without touching keys',
      () async {
        await expectLater(
          database.addWorkoutLog('', _workoutLog(userId: '', id: 'workout')),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          database.saveWorkoutSetLogs('', [_setLog(id: 'set')]),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          database.saveProgressionRule('', _rule(userId: '', id: 'rule')),
          throwsA(isA<ArgumentError>()),
        );
        expect(await _raw('', 'workout_logs'), isNull);
        expect(await _raw('', 'workout_set_logs'), isNull);
        expect(await _raw('', 'progression_rules'), isNull);
      },
    );

    test(
      'a workout mutation leaves every unrelated key byte-for-byte intact',
      () async {
        const userId = 'isolation-owner';
        final workoutRaw = jsonEncode([
          _workoutLog(userId: userId, id: 'legacy').toJson(),
        ]);
        final setRaw = jsonEncode([_setLog(id: 'set-sentinel').toJson()]);
        final ruleRaw = jsonEncode([
          _rule(userId: userId, id: 'rule-sentinel').toJson(),
        ]);
        const opaqueRaw = 'opaque unrelated payload: {not-json';
        FlutterSecureStorage.setMockInitialValues({
          _key(userId, 'workout_logs'): workoutRaw,
          _key(userId, 'workout_set_logs'): setRaw,
          _key(userId, 'progression_rules'): ruleRaw,
          _key(userId, 'diet_logs'): opaqueRaw,
        });

        await database.addWorkoutLog(
          userId,
          _workoutLog(userId: userId, id: 'new'),
        );

        expect(await _raw(userId, 'workout_set_logs'), setRaw);
        expect(await _raw(userId, 'progression_rules'), ruleRaw);
        expect(await _raw(userId, 'diet_logs'), opaqueRaw);
      },
    );

    test('concurrent singular training saves retain all programs', () async {
      const userId = 'training-concurrency-owner';

      await Future.wait(
        List.generate(
          20,
          (index) => database.saveTrainingProgram(
            userId,
            _program(userId: userId, id: 'program-$index'),
          ),
        ),
      );

      final programs = await database.getTrainingPrograms(userId);
      expect(programs, hasLength(20));
      expect(programs.map((program) => program.id).toSet(), hasLength(20));
      expect(
        _envelope((await _raw(userId, 'training_programs'))!)['schemaVersion'],
        1,
      );
    });
  });
}
