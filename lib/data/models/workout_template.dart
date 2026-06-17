
class WorkoutTemplate {
  final String id;
  final String name;
  final List<TemplateExercise> exercises;

  const WorkoutTemplate({required this.id, required this.name, required this.exercises});

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) => WorkoutTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises: (json['exercises'] as List).map((e) => TemplateExercise.fromJson(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

class TemplateExercise {
  final String exerciseId;
  final int defaultSets;
  final int defaultReps;
  final double defaultWeight;

  const TemplateExercise({required this.exerciseId, this.defaultSets = 3, this.defaultReps = 10, this.defaultWeight = 0});

  factory TemplateExercise.fromJson(Map<String, dynamic> json) => TemplateExercise(
    exerciseId: json['exerciseId'] as String,
    defaultSets: json['defaultSets'] as int? ?? 3,
    defaultReps: json['defaultReps'] as int? ?? 10,
    defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {'exerciseId': exerciseId, 'defaultSets': defaultSets, 'defaultReps': defaultReps, 'defaultWeight': defaultWeight};
}
