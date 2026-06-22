enum ProgressionType { fixedWeight, percentWeight, reps, doubleProgression }

ProgressionType _typeFromString(String? value) {
  switch (value) {
    case 'fixedWeight':
      return ProgressionType.fixedWeight;
    case 'percentWeight':
      return ProgressionType.percentWeight;
    case 'reps':
      return ProgressionType.reps;
    case 'doubleProgression':
      return ProgressionType.doubleProgression;
    default:
      return ProgressionType.fixedWeight;
  }
}

class ProgressionRule {
  final String id;
  final String userId;
  final String exerciseId;
  final ProgressionType type;
  final bool enabled;
  final double increment;
  final int targetSets;
  final int targetReps;
  final int? minReps;
  final int? maxReps;
  final double? defaultWeightKg;
  final int? defaultSets;
  final int? defaultReps;
  final bool onlyIfCompleted;

  const ProgressionRule({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.type,
    this.enabled = true,
    this.increment = 2.5,
    this.targetSets = 3,
    this.targetReps = 8,
    this.minReps,
    this.maxReps,
    this.defaultWeightKg,
    this.defaultSets,
    this.defaultReps,
    this.onlyIfCompleted = true,
  });

  factory ProgressionRule.fromJson(Map<String, dynamic> json) =>
      ProgressionRule(
        id: json['id'] as String,
        userId: json['userId'] as String,
        exerciseId: json['exerciseId'] as String,
        type: _typeFromString(json['type'] as String?),
        enabled: json['enabled'] as bool? ?? true,
        increment: (json['increment'] as num?)?.toDouble() ?? 2.5,
        targetSets: json['targetSets'] as int? ?? 3,
        targetReps: json['targetReps'] as int? ?? 8,
        minReps: json['minReps'] as int?,
        maxReps: json['maxReps'] as int?,
        defaultWeightKg: (json['defaultWeightKg'] as num?)?.toDouble(),
        defaultSets: json['defaultSets'] as int?,
        defaultReps: json['defaultReps'] as int?,
        onlyIfCompleted: json['onlyIfCompleted'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'exerciseId': exerciseId,
    'type': type.name,
    'enabled': enabled,
    'increment': increment,
    'targetSets': targetSets,
    'targetReps': targetReps,
    if (minReps != null) 'minReps': minReps,
    if (maxReps != null) 'maxReps': maxReps,
    if (defaultWeightKg != null) 'defaultWeightKg': defaultWeightKg,
    if (defaultSets != null) 'defaultSets': defaultSets,
    if (defaultReps != null) 'defaultReps': defaultReps,
    'onlyIfCompleted': onlyIfCompleted,
  };

  ProgressionRule copyWith({
    String? id,
    String? userId,
    String? exerciseId,
    ProgressionType? type,
    bool? enabled,
    double? increment,
    int? targetSets,
    int? targetReps,
    int? minReps,
    int? maxReps,
    double? defaultWeightKg,
    int? defaultSets,
    int? defaultReps,
    bool? onlyIfCompleted,
    bool clearMinReps = false,
    bool clearMaxReps = false,
    bool clearDefaultWeightKg = false,
    bool clearDefaultSets = false,
    bool clearDefaultReps = false,
  }) {
    return ProgressionRule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseId: exerciseId ?? this.exerciseId,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      increment: increment ?? this.increment,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      minReps: clearMinReps ? null : (minReps ?? this.minReps),
      maxReps: clearMaxReps ? null : (maxReps ?? this.maxReps),
      defaultWeightKg: clearDefaultWeightKg
          ? null
          : (defaultWeightKg ?? this.defaultWeightKg),
      defaultSets: clearDefaultSets ? null : (defaultSets ?? this.defaultSets),
      defaultReps: clearDefaultReps ? null : (defaultReps ?? this.defaultReps),
      onlyIfCompleted: onlyIfCompleted ?? this.onlyIfCompleted,
    );
  }
}
