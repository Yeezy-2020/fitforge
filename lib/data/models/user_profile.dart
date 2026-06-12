enum FitnessGoal { loseFat, buildMuscle, maintain }

enum Gender { male, female }

class UserProfile {
  final String id;
  final String? email;
  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final FitnessGoal goal;
  final double? bodyFatPct;
  final String? displayName;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.email,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    this.bodyFatPct,
    this.displayName,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String?,
    gender: Gender.values.firstWhere(
      (e) => e.name == json['gender'],
      orElse: () => Gender.male,
    ),
    age: json['age'] as int,
    heightCm: (json['heightCm'] as num).toDouble(),
    weightKg: (json['weightKg'] as num).toDouble(),
    goal: FitnessGoal.values.firstWhere(
      (e) => e.name == json['goal'],
      orElse: () => FitnessGoal.maintain,
    ),
    bodyFatPct:
        json['bodyFatPct'] != null
            ? (json['bodyFatPct'] as num).toDouble()
            : null,
    displayName: json['displayName'] as String?,
    createdAt:
        json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'gender': gender.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal.name,
    if (email != null) 'email': email,
    if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
    if (displayName != null) 'displayName': displayName,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}
