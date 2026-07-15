import '../../data/models/progression_rule.dart';
import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';

const trainingSyncV1Enabled = bool.fromEnvironment(
  'FITFORGE_TRAINING_SYNC_V1',
  defaultValue: false,
);

enum TrainingSyncDomain {
  program('program'),
  rule('rule'),
  workout('workout'),
  setLog('set');

  final String wireName;

  const TrainingSyncDomain(this.wireName);

  static TrainingSyncDomain parse(String value) => values.firstWhere(
    (domain) => domain.wireName == value,
    orElse: () =>
        throw FormatException('Unknown training sync domain: $value.'),
  );
}

enum TrainingSyncOperation {
  upsert('upsert'),
  delete('delete');

  final String wireName;

  const TrainingSyncOperation(this.wireName);

  static TrainingSyncOperation parse(String value) => values.firstWhere(
    (operation) => operation.wireName == value,
    orElse: () =>
        throw FormatException('Unknown training sync operation: $value.'),
  );
}

class TrainingSyncMutation {
  final String userId;
  final TrainingSyncDomain domain;
  final String entityId;
  final TrainingSyncOperation operation;
  final Map<String, dynamic>? payload;
  final String token;

  const TrainingSyncMutation({
    required this.userId,
    required this.domain,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.token,
  });

  factory TrainingSyncMutation.fromJson(
    Map<String, dynamic> json, {
    required String expectedUserId,
  }) {
    final userId = _requiredString(json, 'userId');
    if (userId != expectedUserId) {
      throw const FormatException(
        'Training sync mutation belongs to a different user.',
      );
    }
    final domain = TrainingSyncDomain.parse(_requiredString(json, 'domain'));
    final operation = TrainingSyncOperation.parse(
      _requiredString(json, 'operation'),
    );
    final entityId = _requiredString(json, 'entityId');
    final token = _requiredString(json, 'token');
    final rawPayload = json['payload'];
    final Map<String, dynamic>? payload;
    if (operation == TrainingSyncOperation.delete) {
      if (rawPayload != null) {
        throw const FormatException(
          'Training sync delete mutation must not contain a payload.',
        );
      }
      payload = null;
    } else {
      if (rawPayload is! Map) {
        throw const FormatException(
          'Training sync upsert mutation requires a payload.',
        );
      }
      payload = Map<String, dynamic>.from(rawPayload);
      _validatePayload(
        domain: domain,
        entityId: entityId,
        userId: userId,
        payload: payload,
      );
    }

    return TrainingSyncMutation(
      userId: userId,
      domain: domain,
      entityId: entityId,
      operation: operation,
      payload: payload,
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'domain': domain.wireName,
    'entityId': entityId,
    'operation': operation.wireName,
    'payload': payload,
    'token': token,
  };

  String get compactKey => '${domain.wireName}:$entityId';

  TrainingProgram decodeProgram() {
    _requireDomain(TrainingSyncDomain.program);
    return TrainingProgram.fromJson(payload!);
  }

  ProgressionRule decodeRule() {
    _requireDomain(TrainingSyncDomain.rule);
    return ProgressionRule.fromJson(payload!);
  }

  WorkoutLog decodeWorkout() {
    _requireDomain(TrainingSyncDomain.workout);
    return WorkoutLog.fromJson(payload!);
  }

  WorkoutSetLog decodeSetLog() {
    _requireDomain(TrainingSyncDomain.setLog);
    return WorkoutSetLog.fromJson(payload!);
  }

  void _requireDomain(TrainingSyncDomain expected) {
    if (operation != TrainingSyncOperation.upsert || domain != expected) {
      throw StateError(
        'Cannot decode ${operation.wireName} ${domain.wireName} as '
        '${expected.wireName}.',
      );
    }
  }
}

void _validatePayload({
  required TrainingSyncDomain domain,
  required String entityId,
  required String userId,
  required Map<String, dynamic> payload,
}) {
  switch (domain) {
    case TrainingSyncDomain.program:
      final program = TrainingProgram.fromJson(payload);
      _requirePayloadIdentity(program.id, program.userId, entityId, userId);
    case TrainingSyncDomain.rule:
      final rule = ProgressionRule.fromJson(payload);
      _requirePayloadIdentity(rule.id, rule.userId, entityId, userId);
    case TrainingSyncDomain.workout:
      final workout = WorkoutLog.fromJson(payload);
      _requirePayloadIdentity(workout.id, workout.userId, entityId, userId);
    case TrainingSyncDomain.setLog:
      final setLog = WorkoutSetLog.fromJson(payload);
      if (setLog.id != entityId) {
        throw const FormatException(
          'Training sync payload id does not match its entity id.',
        );
      }
  }
}

void _requirePayloadIdentity(
  String payloadId,
  String payloadUserId,
  String entityId,
  String userId,
) {
  if (payloadId != entityId) {
    throw const FormatException(
      'Training sync payload id does not match its entity id.',
    );
  }
  if (payloadUserId != userId) {
    throw const FormatException(
      'Training sync payload belongs to a different user.',
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected non-empty string for $key.');
  }
  return value;
}
