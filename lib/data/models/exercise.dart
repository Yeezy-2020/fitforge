class Exercise {
  final String id;
  final String name;
  final String? nameEn;
  final String bodyPart;
  final String? bodyPartEn;
  final String? category;
  final String? targetMuscle;
  final String? targetMuscleEn;
  final String? instructions;
  final String? instructionsEn;
  final String? commonMistakes;
  final String? commonMistakesEn;
  final String? imageUrl;
  final String? note;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    this.nameEn,
    this.bodyPartEn,
    this.category,
    this.targetMuscle,
    this.targetMuscleEn,
    this.instructions,
    this.instructionsEn,
    this.commonMistakes,
    this.commonMistakesEn,
    this.imageUrl,
    this.note,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    bodyPart: json['bodyPart'] as String,
    nameEn: json['nameEn'] as String?,
    bodyPartEn: json['bodyPartEn'] as String?,
    category: json['category'] as String?,
    targetMuscle: json['targetMuscle'] as String?,
    targetMuscleEn: json['targetMuscleEn'] as String?,
    instructions: json['instructions'] as String?,
    instructionsEn: json['instructionsEn'] as String?,
    commonMistakes: json['commonMistakes'] as String?,
    commonMistakesEn: json['commonMistakesEn'] as String?,
    imageUrl: json['imageUrl'] as String?,
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'bodyPart': bodyPart,
    if (nameEn != null) 'nameEn': nameEn,
    if (bodyPartEn != null) 'bodyPartEn': bodyPartEn,
    if (category != null) 'category': category,
    if (targetMuscle != null) 'targetMuscle': targetMuscle,
    if (targetMuscleEn != null) 'targetMuscleEn': targetMuscleEn,
    if (instructions != null) 'instructions': instructions,
    if (instructionsEn != null) 'instructionsEn': instructionsEn,
    if (commonMistakes != null) 'commonMistakes': commonMistakes,
    if (commonMistakesEn != null) 'commonMistakesEn': commonMistakesEn,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (note != null) 'note': note,
  };

  String displayName(bool isEnglish) =>
      isEnglish && nameEn != null ? nameEn! : name;

  String displayBodyPart(bool isEnglish) =>
      isEnglish && bodyPartEn != null ? bodyPartEn! : bodyPart;

  String displayInstructions(bool isEnglish) =>
      isEnglish && instructionsEn != null ? instructionsEn! : instructions ?? '';

  String displayMistakes(bool isEnglish) =>
      isEnglish && commonMistakesEn != null ? commonMistakesEn! : commonMistakes ?? '';

  String displayTargetMuscle(bool isEnglish) =>
      isEnglish && targetMuscleEn != null ? targetMuscleEn! : targetMuscle ?? '';
}
