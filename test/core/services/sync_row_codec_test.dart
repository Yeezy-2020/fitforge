import 'package:fitforge/core/services/sync_row_codec.dart';
import 'package:fitforge/data/models/progression_rule.dart';
import 'package:fitforge/data/models/training_program.dart';
import 'package:fitforge/data/models/workout_log.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _otherUserId = '22222222-2222-4222-8222-222222222222';
const _workoutId = '33333333-3333-4333-8333-333333333333';

void main() {
  group('WorkoutLog program slot JSON', () {
    test('reads legacy JSON without program slot identifiers', () {
      final log = WorkoutLog.fromJson({
        'id': _workoutId,
        'userId': _userId,
        'exerciseId': 'bench-press',
        'date': '2026-07-13T00:00:00.000Z',
        'sets': 3,
        'reps': 8,
        'weightKg': 80,
      });

      expect(log.hasProgramSlot, isFalse);
      expect(log.programId, isNull);
      expect(log.programDayId, isNull);
      expect(log.programExerciseId, isNull);
      expect(log.toJson(), isNot(contains('programId')));
    });

    test('round-trips a complete program slot', () {
      final original = _workoutLog();
      final decoded = WorkoutLog.fromJson(original.toJson());

      expect(decoded.hasProgramSlot, isTrue);
      expect(decoded.programId, 'program-a');
      expect(decoded.programDayId, 'day-a');
      expect(decoded.programExerciseId, 'program-exercise-a');
    });

    test('rejects a partial program slot in JSON', () {
      expect(
        () => WorkoutLog.fromJson({
          'id': _workoutId,
          'userId': _userId,
          'exerciseId': 'bench-press',
          'programId': 'program-a',
          'date': '2026-07-13T00:00:00.000Z',
          'sets': 3,
          'reps': 8,
          'weightKg': 80,
        }),
        throwsFormatException,
      );
    });

    test('asserts against a partial program slot at construction', () {
      expect(
        () => WorkoutLog(
          id: _workoutId,
          userId: _userId,
          exerciseId: 'bench-press',
          programId: 'program-a',
          date: DateTime.utc(2026, 7, 13),
          sets: 3,
          reps: 8,
          weightKg: 80,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('WorkoutSetLog program day JSON', () {
    test('reads legacy JSON without a program day id', () {
      final log = WorkoutSetLog.fromJson({
        'id': 'set-a',
        'workoutLogId': _workoutId,
        'programId': 'program-a',
        'programExerciseId': 'program-exercise-a',
        'setIndex': 0,
        'reps': 8,
        'weightKg': 80,
        'completed': true,
      });

      expect(log.programDayId, isNull);
      expect(log.toJson(), isNot(contains('programDayId')));
    });

    test('round-trips and can clear a program day id', () {
      final original = _workoutSetLog();
      final decoded = WorkoutSetLog.fromJson(original.toJson());

      expect(decoded.programDayId, 'day-a');
      expect(decoded.copyWith(clearProgramDayId: true).programDayId, isNull);
    });
  });

  group('SyncRowCodec', () {
    test('round-trips workout rows with program slot identifiers', () {
      final original = _workoutLog();
      final row = SyncRowCodec.workoutLogToRow(
        original,
        currentUserId: _userId,
      );
      final decoded = SyncRowCodec.workoutLogFromRow(
        row,
        currentUserId: _userId,
      );

      expect(row['id'], _workoutId);
      expect(row['user_id'], _userId);
      expect(row['program_id'], 'program-a');
      expect(row['program_day_id'], 'day-a');
      expect(row['program_exercise_id'], 'program-exercise-a');
      expect(decoded.userId, original.userId);
      expect(
        (decoded.date.year, decoded.date.month, decoded.date.day),
        (original.date.year, original.date.month, original.date.day),
      );
      expect(decoded.programDayId, original.programDayId);
      expect(decoded.createdAt, original.createdAt);
    });

    test('legacy workout rows omit columns that require the new migration', () {
      final row = SyncRowCodec.workoutLogToLegacyRow(
        _workoutLog(),
        currentUserId: _userId,
      );

      expect(row['id'], _workoutId);
      expect(row['user_id'], _userId);
      expect(row, isNot(contains('program_id')));
      expect(row, isNot(contains('program_day_id')));
      expect(row, isNot(contains('program_exercise_id')));
    });

    test('rejects a remote workout row with a partial program slot', () {
      final row = SyncRowCodec.workoutLogToRow(
        _workoutLog(),
        currentUserId: _userId,
      )..['program_day_id'] = null;

      expect(
        () => SyncRowCodec.workoutLogFromRow(row, currentUserId: _userId),
        throwsFormatException,
      );
    });

    test('round-trips training program JSON document rows', () {
      final original = _trainingProgram();
      final row = SyncRowCodec.trainingProgramToRow(
        original,
        currentUserId: _userId,
      );
      final decoded = SyncRowCodec.trainingProgramFromRow(
        row,
        currentUserId: _userId,
      );

      expect(row['id'], original.id);
      expect(row['user_id'], _userId);
      expect(row['document'], original.toJson());
      expect(row, isNot(contains('updated_at')));
      expect(decoded.id, original.id);
      expect(decoded.userId, original.userId);
      expect(decoded.name, original.name);
      expect(decoded.days.single.id, original.days.single.id);
    });

    test('round-trips progression rule JSON document rows', () {
      const original = ProgressionRule(
        id: 'rule-a',
        userId: _userId,
        exerciseId: 'bench-press',
        type: ProgressionType.doubleProgression,
        minReps: 8,
        maxReps: 12,
      );
      final row = SyncRowCodec.progressionRuleToRow(
        original,
        currentUserId: _userId,
      );
      final decoded = SyncRowCodec.progressionRuleFromRow(
        row,
        currentUserId: _userId,
      );

      expect(row['document'], original.toJson());
      expect(decoded.id, original.id);
      expect(decoded.userId, original.userId);
      expect(decoded.type, original.type);
      expect(decoded.minReps, original.minReps);
      expect(decoded.maxReps, original.maxReps);
    });

    test('round-trips normalized workout set rows', () {
      final original = _workoutSetLog();
      final row = SyncRowCodec.workoutSetLogToRow(
        original,
        currentUserId: _userId,
      );
      final decoded = SyncRowCodec.workoutSetLogFromRow(
        row,
        currentUserId: _userId,
      );

      expect(row['id'], 'set-a');
      expect(row['user_id'], _userId);
      expect(row['workout_log_id'], _workoutId);
      expect(row['program_day_id'], 'day-a');
      expect(decoded.toJson(), original.toJson());
    });

    test('rejects a legacy set without a complete remote slot', () {
      final legacy = _workoutSetLog().copyWith(clearProgramDayId: true);

      expect(
        () => SyncRowCodec.workoutSetLogToRow(legacy, currentUserId: _userId),
        throwsFormatException,
      );
    });

    test('rejects owner mismatch on model writes', () {
      expect(
        () => SyncRowCodec.workoutLogToRow(
          _workoutLog(userId: _otherUserId),
          currentUserId: _userId,
        ),
        throwsA(isA<SyncOwnerMismatchException>()),
      );
      expect(
        () => SyncRowCodec.trainingProgramToRow(
          _trainingProgram(userId: _otherUserId),
          currentUserId: _userId,
        ),
        throwsA(isA<SyncOwnerMismatchException>()),
      );
    });

    test('rejects owner mismatch on remote rows and JSON documents', () {
      final setRow = SyncRowCodec.workoutSetLogToRow(
        _workoutSetLog(),
        currentUserId: _userId,
      )..['user_id'] = _otherUserId;
      expect(
        () => SyncRowCodec.workoutSetLogFromRow(setRow, currentUserId: _userId),
        throwsA(isA<SyncOwnerMismatchException>()),
      );

      final programRow = SyncRowCodec.trainingProgramToRow(
        _trainingProgram(),
        currentUserId: _userId,
      );
      final document = Map<String, dynamic>.from(programRow['document'] as Map)
        ..['userId'] = _otherUserId;
      programRow['document'] = document;
      expect(
        () => SyncRowCodec.trainingProgramFromRow(
          programRow,
          currentUserId: _userId,
        ),
        throwsA(isA<SyncOwnerMismatchException>()),
      );
    });

    test('rejects a document whose id differs from its row id', () {
      final row = SyncRowCodec.progressionRuleToRow(
        const ProgressionRule(
          id: 'rule-a',
          userId: _userId,
          exerciseId: 'bench-press',
          type: ProgressionType.fixedWeight,
        ),
        currentUserId: _userId,
      )..['id'] = 'rule-b';

      expect(
        () => SyncRowCodec.progressionRuleFromRow(row, currentUserId: _userId),
        throwsFormatException,
      );
    });
  });
}

WorkoutLog _workoutLog({String userId = _userId}) => WorkoutLog(
  id: _workoutId,
  userId: userId,
  exerciseId: 'bench-press',
  programId: 'program-a',
  programDayId: 'day-a',
  programExerciseId: 'program-exercise-a',
  date: DateTime.utc(2026, 7, 13),
  sets: 3,
  reps: 8,
  weightKg: 80,
  note: 'Working set',
  createdAt: DateTime.utc(2026, 7, 13, 8, 30),
);

WorkoutSetLog _workoutSetLog() => const WorkoutSetLog(
  id: 'set-a',
  workoutLogId: _workoutId,
  programId: 'program-a',
  programDayId: 'day-a',
  programExerciseId: 'program-exercise-a',
  setIndex: 0,
  reps: 8,
  weightKg: 80,
  completed: true,
);

TrainingProgram _trainingProgram({String userId = _userId}) => TrainingProgram(
  id: 'program-a',
  userId: userId,
  name: 'Strength A',
  days: const [
    ProgramDay(
      id: 'day-a',
      name: 'Day A',
      exercises: [
        ProgramExercise(id: 'program-exercise-a', exerciseId: 'bench-press'),
      ],
    ),
  ],
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 13),
);
