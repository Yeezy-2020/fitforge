import '../../data/models/progression_rule.dart';
import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';

class SyncOwnerMismatchException implements Exception {
  final String expectedUserId;
  final String actualUserId;
  final String recordType;

  const SyncOwnerMismatchException({
    required this.expectedUserId,
    required this.actualUserId,
    required this.recordType,
  });

  @override
  String toString() =>
      'SyncOwnerMismatchException: $recordType belongs to $actualUserId, '
      'not $expectedUserId.';
}

abstract final class SyncRowCodec {
  static Map<String, dynamic> workoutLogToRow(
    WorkoutLog log, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: log.userId,
      recordType: 'workout log',
    );
    _requireValidWorkoutSlot(
      log.programId,
      log.programDayId,
      log.programExerciseId,
    );

    return {
      'id': _requireNonEmpty(log.id, 'Workout log id'),
      'user_id': currentUserId,
      'exercise_id': _requireNonEmpty(log.exerciseId, 'Exercise id'),
      'program_id': log.programId,
      'program_day_id': log.programDayId,
      'program_exercise_id': log.programExerciseId,
      'date': _dateOnly(log.date),
      'sets': log.sets,
      'reps': log.reps,
      'weight_kg': log.weightKg,
      'note': log.note,
      if (log.createdAt != null)
        'created_at': log.createdAt!.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> workoutLogToLegacyRow(
    WorkoutLog log, {
    required String currentUserId,
  }) {
    return workoutLogToRow(log, currentUserId: currentUserId)
      ..remove('program_id')
      ..remove('program_day_id')
      ..remove('program_exercise_id');
  }

  static WorkoutLog workoutLogFromRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    final owner = _requiredString(row, 'user_id');
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: owner,
      recordType: 'workout log row',
    );
    final programId = _optionalString(row, 'program_id');
    final programDayId = _optionalString(row, 'program_day_id');
    final programExerciseId = _optionalString(row, 'program_exercise_id');
    _requireValidWorkoutSlot(programId, programDayId, programExerciseId);

    return WorkoutLog(
      id: _requiredString(row, 'id'),
      userId: owner,
      exerciseId: _requiredString(row, 'exercise_id'),
      programId: programId,
      programDayId: programDayId,
      programExerciseId: programExerciseId,
      date: _requiredDateTime(row, 'date'),
      sets: _requiredInt(row, 'sets'),
      reps: _requiredInt(row, 'reps'),
      weightKg: _requiredDouble(row, 'weight_kg'),
      note: _optionalString(row, 'note', allowEmpty: true),
      createdAt: _optionalDateTime(row, 'created_at'),
    );
  }

  static Map<String, dynamic> trainingProgramToRow(
    TrainingProgram program, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: program.userId,
      recordType: 'training program',
    );

    return {
      'id': _requireNonEmpty(program.id, 'Training program id'),
      'user_id': currentUserId,
      'document': program.toJson(),
    };
  }

  static TrainingProgram trainingProgramFromRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    final rowOwner = _requiredString(row, 'user_id');
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: rowOwner,
      recordType: 'training program row',
    );
    final rowId = _requiredString(row, 'id');
    final document = _requiredDocument(row, 'document');
    _requireDocumentIdentity(
      document: document,
      rowId: rowId,
      currentUserId: currentUserId,
      recordType: 'training program document',
    );
    return TrainingProgram.fromJson(document);
  }

  static Map<String, dynamic> progressionRuleToRow(
    ProgressionRule rule, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: rule.userId,
      recordType: 'progression rule',
    );

    return {
      'id': _requireNonEmpty(rule.id, 'Progression rule id'),
      'user_id': currentUserId,
      'document': rule.toJson(),
    };
  }

  static ProgressionRule progressionRuleFromRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    final rowOwner = _requiredString(row, 'user_id');
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: rowOwner,
      recordType: 'progression rule row',
    );
    final rowId = _requiredString(row, 'id');
    final document = _requiredDocument(row, 'document');
    _requireDocumentIdentity(
      document: document,
      rowId: rowId,
      currentUserId: currentUserId,
      recordType: 'progression rule document',
    );
    return ProgressionRule.fromJson(document);
  }

  static Map<String, dynamic> workoutSetLogToRow(
    WorkoutSetLog log, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    return {
      'id': _requireNonEmpty(log.id, 'Workout set log id'),
      'user_id': currentUserId,
      'workout_log_id': _requireNonEmpty(
        log.workoutLogId,
        'Parent workout log id',
      ),
      'program_id': _requireNonEmpty(log.programId, 'Training program id'),
      'program_day_id': _requireNonEmpty(
        log.programDayId ?? '',
        'Program day id',
      ),
      'program_exercise_id': _requireNonEmpty(
        log.programExerciseId,
        'Program exercise id',
      ),
      'set_index': log.setIndex,
      'reps': log.reps,
      'weight_kg': log.weightKg,
      'completed': log.completed,
    };
  }

  static WorkoutSetLog workoutSetLogFromRow(
    Map<String, dynamic> row, {
    required String currentUserId,
  }) {
    _requireCurrentUser(currentUserId);
    final owner = _requiredString(row, 'user_id');
    _requireOwner(
      expectedUserId: currentUserId,
      actualUserId: owner,
      recordType: 'workout set log row',
    );
    return WorkoutSetLog(
      id: _requiredString(row, 'id'),
      workoutLogId: _requiredString(row, 'workout_log_id'),
      programId: _requiredString(row, 'program_id'),
      programDayId: _requiredString(row, 'program_day_id'),
      programExerciseId: _requiredString(row, 'program_exercise_id'),
      setIndex: _requiredInt(row, 'set_index'),
      reps: _requiredInt(row, 'reps'),
      weightKg: _requiredDouble(row, 'weight_kg'),
      completed: _requiredBool(row, 'completed'),
    );
  }
}

void _requireCurrentUser(String currentUserId) {
  _requireNonEmpty(currentUserId, 'Current user id');
}

void _requireOwner({
  required String expectedUserId,
  required String actualUserId,
  required String recordType,
}) {
  if (expectedUserId != actualUserId) {
    throw SyncOwnerMismatchException(
      expectedUserId: expectedUserId,
      actualUserId: actualUserId,
      recordType: recordType,
    );
  }
}

void _requireDocumentIdentity({
  required Map<String, dynamic> document,
  required String rowId,
  required String currentUserId,
  required String recordType,
}) {
  final documentId = _requiredString(document, 'id');
  if (documentId != rowId) {
    throw FormatException('$recordType id does not match its row id.');
  }
  final documentOwner = _requiredString(document, 'userId');
  _requireOwner(
    expectedUserId: currentUserId,
    actualUserId: documentOwner,
    recordType: recordType,
  );
}

void _requireValidWorkoutSlot(
  String? programId,
  String? programDayId,
  String? programExerciseId,
) {
  final presentCount = [
    programId,
    programDayId,
    programExerciseId,
  ].where((value) => value != null).length;
  if (presentCount != 0 && presentCount != 3) {
    throw const FormatException(
      'Workout program slot identifiers must be all null or all non-null.',
    );
  }
  if ([
    programId,
    programDayId,
    programExerciseId,
  ].any((value) => value != null && value.isEmpty)) {
    throw const FormatException(
      'Workout program slot identifiers must not be empty.',
    );
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _requireNonEmpty(String value, String label) {
  if (value.isEmpty) throw FormatException('$label must not be empty.');
  return value;
}

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected non-empty string for $key.');
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> row,
  String key, {
  bool allowEmpty = false,
}) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String || (!allowEmpty && value.isEmpty)) {
    throw FormatException('Expected string or null for $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('Expected integer for $key.');
}

double _requiredDouble(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('Expected finite number for $key.');
  }
  return value.toDouble();
}

bool _requiredBool(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! bool) throw FormatException('Expected boolean for $key.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String) throw FormatException('Expected timestamp for $key.');
  return DateTime.parse(value);
}

DateTime? _optionalDateTime(Map<String, dynamic> row, String key) {
  if (row[key] == null) return null;
  return _requiredDateTime(row, key);
}

Map<String, dynamic> _requiredDocument(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! Map) throw FormatException('Expected JSON object for $key.');
  try {
    return Map<String, dynamic>.from(value);
  } on TypeError {
    throw FormatException('Expected string-keyed JSON object for $key.');
  }
}
