import 'dart:convert';

import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/repositories/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _storage = FlutterSecureStorage();
const _storageType = 'training_programs';

String _storageKey(String userId) => '$userId:$_storageType';

TrainingProgram _program({
  required String userId,
  required String id,
  int periodCycles = 6,
}) {
  final timestamp = DateTime.utc(2025, 1, 2, 3, 4, 5);
  return TrainingProgram(
    id: id,
    userId: userId,
    name: 'Program $id',
    createdAt: timestamp,
    updatedAt: timestamp,
    days: [
      ProgramDay(
        id: '$id-day',
        name: 'Day $id',
        exercises: [
          ProgramExercise(
            id: '$id-program-exercise',
            exerciseId: '$id-exercise',
            targetSets: 4,
            minReps: 6,
            maxReps: 10,
            startingWeightKg: 62.5,
            progressionScheme: ProgressionScheme(
              type: ProgressionSchemeType.linearWeight,
              weightIncrementKg: 2.5,
              percentIncrement: 5,
              periodCycles: periodCycles,
              deloadPercent: 0.6,
            ),
          ),
        ],
      ),
    ],
  );
}

Map<String, dynamic> _legacyProgramJson({
  required String userId,
  required String id,
  int periodWeeks = 6,
}) {
  final json = _program(
    userId: userId,
    id: id,
    periodCycles: periodWeeks,
  ).toJson();
  final days = json['days'] as List<dynamic>;
  final day = days.single as Map<String, dynamic>;
  final exercises = day['exercises'] as List<dynamic>;
  final exercise = exercises.single as Map<String, dynamic>;
  final scheme = exercise['progressionScheme'] as Map<String, dynamic>;
  scheme['periodWeeks'] = scheme.remove('periodCycles');
  return json;
}

String _v1Raw(List<Map<String, dynamic>> programs) =>
    jsonEncode({'schemaVersion': 1, 'data': programs});

Future<String?> _rawFor(String userId) =>
    _storage.read(key: _storageKey(userId));

Map<String, dynamic> _decodeEnvelope(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;

Map<String, dynamic> _storedScheme(Map<String, dynamic> programJson) {
  final days = programJson['days'] as List<dynamic>;
  final day = days.single as Map<String, dynamic>;
  final exercises = day['exercises'] as List<dynamic>;
  final exercise = exercises.single as Map<String, dynamic>;
  return exercise['progressionScheme'] as Map<String, dynamic>;
}

void main() {
  final database = AppDatabase.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('training program storage v1', () {
    test(
      'missing key and empty user read as empty without creating storage',
      () async {
        expect(await database.getTrainingPrograms('missing-user'), isEmpty);
        expect(await database.getTrainingPrograms(''), isEmpty);

        expect(await _rawFor('missing-user'), isNull);
        expect(await _rawFor(''), isNull);
      },
    );

    test('public save writes a v1 envelope and roundtrips its data', () async {
      final original = _program(userId: 'owner', id: 'alpha');

      await database.saveTrainingPrograms('owner', [original]);

      final raw = await _rawFor('owner');
      expect(raw, isNotNull);
      final envelope = _decodeEnvelope(raw!);
      expect(envelope.keys, unorderedEquals(['schemaVersion', 'data']));
      expect(envelope['schemaVersion'], 1);
      final data = envelope['data'] as List<dynamic>;
      expect(data, hasLength(1));
      final stored = data.single as Map<String, dynamic>;
      expect(stored['id'], 'alpha');
      expect(stored['userId'], 'owner');
      final scheme = _storedScheme(stored);
      expect(scheme['periodCycles'], 6);
      expect(scheme.containsKey('periodWeeks'), isFalse);

      final restored = await database.getTrainingPrograms('owner');
      expect(restored, hasLength(1));
      expect(restored.single.id, original.id);
      expect(restored.single.userId, original.userId);
      expect(
        restored
            .single
            .days
            .single
            .exercises
            .single
            .progressionScheme
            .periodCycles,
        6,
      );
    });

    test(
      'legacy read is non-mutating and the next bulk save upgrades it',
      () async {
        const userId = 'legacy-owner';
        final legacyRaw = jsonEncode([
          _legacyProgramJson(userId: userId, id: 'legacy', periodWeeks: 8),
        ]);
        FlutterSecureStorage.setMockInitialValues({
          _storageKey(userId): legacyRaw,
        });

        final programs = await database.getTrainingPrograms(userId);

        expect(programs, hasLength(1));
        expect(
          programs
              .single
              .days
              .single
              .exercises
              .single
              .progressionScheme
              .periodCycles,
          8,
        );
        expect(await _rawFor(userId), legacyRaw);

        await database.saveTrainingPrograms(userId, programs);

        final upgradedRaw = await _rawFor(userId);
        final envelope = _decodeEnvelope(upgradedRaw!);
        expect(envelope['schemaVersion'], 1);
        final upgraded =
            (envelope['data'] as List<dynamic>).single as Map<String, dynamic>;
        expect(upgraded['id'], 'legacy');
        expect(upgraded['name'], 'Program legacy');
        final scheme = _storedScheme(upgraded);
        expect(scheme['periodCycles'], 8);
        expect(scheme.containsKey('periodWeeks'), isFalse);
        expect(upgradedRaw, isNot(contains('periodWeeks')));
      },
    );

    test(
      'appending to legacy data upgrades without losing the legacy item',
      () async {
        const userId = 'append-owner';
        final legacyRaw = jsonEncode([
          _legacyProgramJson(userId: userId, id: 'legacy', periodWeeks: 7),
        ]);
        FlutterSecureStorage.setMockInitialValues({
          _storageKey(userId): legacyRaw,
        });

        await database.saveTrainingProgram(
          userId,
          _program(userId: userId, id: 'appended', periodCycles: 3),
        );

        final raw = await _rawFor(userId);
        final envelope = _decodeEnvelope(raw!);
        expect(envelope['schemaVersion'], 1);
        final data = (envelope['data'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          data.map((item) => item['id']),
          unorderedEquals(['legacy', 'appended']),
        );
        final legacy = data.singleWhere((item) => item['id'] == 'legacy');
        expect(_storedScheme(legacy)['periodCycles'], 7);
        expect(raw, isNot(contains('periodWeeks')));
      },
    );

    test(
      'future schema version is rejected without rewriting raw data',
      () async {
        const userId = 'future-owner';
        final originalRaw = jsonEncode({
          'schemaVersion': 2,
          'data': <Object>[],
        });
        FlutterSecureStorage.setMockInitialValues({
          _storageKey(userId): originalRaw,
        });

        await expectLater(
          database.getTrainingPrograms(userId),
          throwsA(isA<UnsupportedStorageVersionException>()),
        );
        expect(await _rawFor(userId), originalRaw);
      },
    );

    final corruptCases = <String, String>{
      'malformed JSON': '{not-json',
      'wrong root type': jsonEncode('not-an-envelope-or-legacy-list'),
      'missing envelope data': jsonEncode({'schemaVersion': 1}),
      'wrong envelope data type': jsonEncode({
        'schemaVersion': 1,
        'data': <String, Object?>{},
      }),
      'wrong schema version type': jsonEncode({
        'schemaVersion': '1',
        'data': <Object>[],
      }),
      'bad data item': jsonEncode({
        'schemaVersion': 1,
        'data': [42],
      }),
    };

    for (final entry in corruptCases.entries) {
      test(
        '${entry.key} is corrupt and remains byte-for-byte unchanged',
        () async {
          const userId = 'corrupt-owner';
          FlutterSecureStorage.setMockInitialValues({
            _storageKey(userId): entry.value,
          });

          await expectLater(
            database.getTrainingPrograms(userId),
            throwsA(isA<CorruptStorageDataException>()),
          );
          expect(await _rawFor(userId), entry.value);
        },
      );
    }

    final guardedBulkSaveCases =
        <({String name, String raw, Matcher expectedError})>[
          (
            name: 'future schema version',
            raw: jsonEncode({'schemaVersion': 2, 'data': <Object>[]}),
            expectedError: isA<UnsupportedStorageVersionException>(),
          ),
          (
            name: 'corrupt payload',
            raw: '{not-json',
            expectedError: isA<CorruptStorageDataException>(),
          ),
        ];

    for (final testCase in guardedBulkSaveCases) {
      test(
        'bulk save rejects existing ${testCase.name} without replacing it',
        () async {
          const userId = 'guarded-bulk-owner';
          FlutterSecureStorage.setMockInitialValues({
            _storageKey(userId): testCase.raw,
          });

          await expectLater(
            database.saveTrainingPrograms(userId, [
              _program(userId: userId, id: 'replacement'),
            ]),
            throwsA(testCase.expectedError),
          );

          final rawAfterRejectedSave = await _rawFor(userId);
          expect(rawAfterRejectedSave, testCase.raw);
          expect(rawAfterRejectedSave, isNot(contains('replacement')));
        },
      );
    }

    for (final format in ['legacy', 'v1']) {
      test(
        '$format stored owner mismatch is corrupt and is not rewritten',
        () async {
          const requestedUser = 'requested-owner';
          final foreign = _program(
            userId: 'foreign-owner',
            id: 'foreign',
          ).toJson();
          final originalRaw = format == 'legacy'
              ? jsonEncode([foreign])
              : _v1Raw([foreign]);
          FlutterSecureStorage.setMockInitialValues({
            _storageKey(requestedUser): originalRaw,
          });

          await expectLater(
            database.getTrainingPrograms(requestedUser),
            throwsA(isA<CorruptStorageDataException>()),
          );
          expect(await _rawFor(requestedUser), originalRaw);
        },
      );
    }

    test('writes reject an empty owner without touching storage', () async {
      await expectLater(
        database.saveTrainingPrograms('', const []),
        throwsA(isA<ArgumentError>()),
      );

      expect(await _rawFor(''), isNull);
    });

    test('bulk and singular writes reject mismatched owners', () async {
      final foreign = _program(userId: 'foreign-owner', id: 'foreign');

      await expectLater(
        database.saveTrainingPrograms('requested-owner', [foreign]),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        database.saveTrainingProgram('requested-owner', foreign),
        throwsA(isA<ArgumentError>()),
      );

      expect(await _rawFor('requested-owner'), isNull);
    });

    test('legacy user A migration never reads or rewrites v1 user B', () async {
      const userA = 'user-a';
      const userB = 'user-b';
      final rawA = jsonEncode([
        _legacyProgramJson(userId: userA, id: 'a-legacy', periodWeeks: 9),
      ]);
      final rawB = _v1Raw([
        _program(userId: userB, id: 'b-v1', periodCycles: 4).toJson(),
      ]);
      FlutterSecureStorage.setMockInitialValues({
        _storageKey(userA): rawA,
        _storageKey(userB): rawB,
      });

      final aPrograms = await database.getTrainingPrograms(userA);
      expect(aPrograms.single.id, 'a-legacy');
      expect(await _rawFor(userA), rawA);
      expect(await _rawFor(userB), rawB);

      await database.saveTrainingProgram(
        userA,
        _program(userId: userA, id: 'a-new'),
      );

      expect(_decodeEnvelope((await _rawFor(userA))!)['schemaVersion'], 1);
      expect(await _rawFor(userB), rawB);
      final bPrograms = await database.getTrainingPrograms(userB);
      expect(bPrograms.single.id, 'b-v1');
      expect(await _rawFor(userB), rawB);
    });

    test(
      'legacy upgrade leaves the same user non-training blob unchanged',
      () async {
        const userId = 'sentinel-owner';
        const nonTrainingKey = '$userId:workout_logs';
        const sentinelRaw = 'opaque workout log sentinel: [not training JSON]';
        final legacyRaw = jsonEncode([
          _legacyProgramJson(userId: userId, id: 'legacy-sentinel'),
        ]);
        FlutterSecureStorage.setMockInitialValues({
          _storageKey(userId): legacyRaw,
          nonTrainingKey: sentinelRaw,
        });

        final programs = await database.getTrainingPrograms(userId);
        await database.saveTrainingPrograms(userId, programs);

        expect(_decodeEnvelope((await _rawFor(userId))!)['schemaVersion'], 1);
        expect(await _storage.read(key: nonTrainingKey), sentinelRaw);
      },
    );

    test('delete mutation keeps remaining data in the v1 envelope', () async {
      const userId = 'delete-owner';
      await database.saveTrainingPrograms(userId, [
        _program(userId: userId, id: 'keep'),
        _program(userId: userId, id: 'delete'),
      ]);

      await database.deleteTrainingProgram(userId, 'delete');

      final raw = await _rawFor(userId);
      final envelope = _decodeEnvelope(raw!);
      expect(envelope['schemaVersion'], 1);
      final data = envelope['data'] as List<dynamic>;
      expect(data, hasLength(1));
      expect((data.single as Map<String, dynamic>)['id'], 'keep');
      expect((await database.getTrainingPrograms(userId)).single.id, 'keep');
    });
  });
}
