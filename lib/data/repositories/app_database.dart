import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/food.dart';
import '../models/diet_log.dart';
import '../models/user_profile.dart';
import '../models/workout_template.dart';
import 'exercise_library.dart';

class AppDatabase {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  String _key(String userId, String type) => '$userId:$type';

  Future<List<Exercise>> getExercises(String userId) async {
    final data = await _storage.read(key: _key(userId, 'exercises'));
    if (data == null) return ExerciseLibrary.defaultExercises;
    final stored = (jsonDecode(data) as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return stored.isNotEmpty ? stored : ExerciseLibrary.defaultExercises;
  }

  Future<void> saveExercises(String userId, List<Exercise> exercises) async {
    await _storage.write(
      key: _key(userId, 'exercises'),
      value: jsonEncode(exercises.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> addExercise(String userId, Exercise exercise) async {
    final exercises = await getExercises(userId);
    exercises.add(exercise);
    await saveExercises(userId, exercises);
  }

  Future<List<WorkoutLog>> getWorkoutLogs(
    String userId,
    DateTime date,
  ) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    if (data == null) return [];
    final dateStr = _dateStr(date);
    return (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .where((log) => _dateStr(log.date) == dateStr)
        .toList();
  }

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(
    String userId,
    DateTime month,
  ) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    if (data == null) return [];
    final monthStr =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    return (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .where((log) => _dateStr(log.date).startsWith(monthStr))
        .toList();
  }

  Future<void> addWorkoutLog(String userId, WorkoutLog log) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    final logs =
        data != null
            ? (jsonDecode(data) as List)
                .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
                .toList()
            : <WorkoutLog>[];
    logs.add(log);
    await _storage.write(
      key: _key(userId, 'workout_logs'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteWorkoutLog(String userId, String logId) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    if (data == null) return;
    final logs =
        (jsonDecode(data) as List)
            .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
            .toList();
    logs.removeWhere((l) => l.id == logId);
    await _storage.write(
      key: _key(userId, 'workout_logs'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<DietLog>> getDietLogs(String userId, DateTime date) async {
    final data = await _storage.read(key: _key(userId, 'diet_logs'));
    if (data == null) return [];
    final dateStr = _dateStr(date);
    return (jsonDecode(data) as List)
        .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
        .where((log) => _dateStr(log.date) == dateStr)
        .toList();
  }

  Future<void> addDietLog(String userId, DietLog log) async {
    final data = await _storage.read(key: _key(userId, 'diet_logs'));
    final logs =
        data != null
            ? (jsonDecode(data) as List)
                .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
                .toList()
            : <DietLog>[];
    logs.add(log);
    await _storage.write(
      key: _key(userId, 'diet_logs'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteDietLog(String userId, String logId) async {
    final data = await _storage.read(key: _key(userId, 'diet_logs'));
    if (data == null) return;
    final logs =
        (jsonDecode(data) as List)
            .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
            .toList();
    logs.removeWhere((l) => l.id == logId);
    await _storage.write(
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
    final foods = await getFoods(userId);
    foods.add(food);
    await _storage.write(
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
    await _storage.write(
      key: _key(userId, 'is_pro'),
      value: isPro.toString(),
    );
  }

  // ---- Sync ----

  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    final existing =
        data != null
            ? (jsonDecode(data) as List)
                .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
                .toList()
            : <WorkoutLog>[];
    final existingIds = existing.map((l) => l.id).toSet();
    for (final log in logs) {
      if (!existingIds.contains(log.id)) {
        existing.add(log);
      }
    }
    await _storage.write(
      key: _key(userId, 'workout_logs'),
      value: jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveDietLogs(String userId, List<DietLog> logs) async {
    final data = await _storage.read(key: _key(userId, 'diet_logs'));
    final existing =
        data != null
            ? (jsonDecode(data) as List)
                .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
                .toList()
            : <DietLog>[];
    final existingIds = existing.map((l) => l.id).toSet();
    for (final log in logs) {
      if (!existingIds.contains(log.id)) {
        existing.add(log);
      }
    }
    await _storage.write(
      key: _key(userId, 'diet_logs'),
      value: jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WorkoutLog>> getUnsyncedWorkoutLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'unsynced_workouts'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addUnsyncedWorkout(String userId, WorkoutLog log) async {
    final unsynced = await getUnsyncedWorkoutLogs(userId);
    unsynced.add(log);
    await _storage.write(
      key: _key(userId, 'unsynced_workouts'),
      value: jsonEncode(unsynced.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clearUnsyncedWorkouts(String userId) async {
    await _storage.delete(key: _key(userId, 'unsynced_workouts'));
  }

  Future<String?> getLastSyncTime(String userId) async {
    return _storage.read(key: _key(userId, 'last_sync'));
  }

  Future<void> setLastSyncTime(String userId) async {
    await _storage.write(key: _key(userId, 'last_sync'), value: DateTime.now().toIso8601String());
  }

  // ---- Templates ----
  Future<List<WorkoutTemplate>> getTemplates(String userId) async {
    final data = await _storage.read(key: _key(userId, 'templates'));
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => WorkoutTemplate.fromJson(e)).toList();
  }

  Future<void> saveTemplate(String userId, WorkoutTemplate template) async {
    final templates = await getTemplates(userId);
    templates.add(template);
    await _storage.write(key: _key(userId, 'templates'), value: jsonEncode(templates.map((t) => t.toJson()).toList()));
  }

  Future<void> deleteTemplate(String userId, String templateId) async {
    final templates = await getTemplates(userId);
    templates.removeWhere((t) => t.id == templateId);
    await _storage.write(key: _key(userId, 'templates'), value: jsonEncode(templates.map((t) => t.toJson()).toList()));
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<Exercise> _defaultExercises() => [
    Exercise(id: 'ex_bench', name: '杠铃卧推', bodyPart: '胸部', category: '力量'),
    Exercise(id: 'ex_dumbell_press', name: '哑铃卧推', bodyPart: '胸部', category: '力量'),
    Exercise(id: 'ex_cable_fly', name: '龙门架夹胸', bodyPart: '胸部', category: '力量'),
    Exercise(id: 'ex_squat', name: '杠铃深蹲', bodyPart: '腿部', category: '力量'),
    Exercise(id: 'ex_legpress', name: '腿举', bodyPart: '腿部', category: '力量'),
    Exercise(id: 'ex_deadlift', name: '硬拉', bodyPart: '背部', category: '力量'),
    Exercise(id: 'ex_pullup', name: '引体向上', bodyPart: '背部', category: '力量'),
    Exercise(id: 'ex_row', name: '杠铃划船', bodyPart: '背部', category: '力量'),
    Exercise(id: 'ex_shoulder_press', name: '哑铃推举', bodyPart: '肩部', category: '力量'),
    Exercise(id: 'ex_lateral_raise', name: '侧平举', bodyPart: '肩部', category: '力量'),
    Exercise(id: 'ex_bicep_curl', name: '杠铃弯举', bodyPart: '手臂', category: '力量'),
    Exercise(id: 'ex_tricep_pushdown', name: '绳索下压', bodyPart: '手臂', category: '力量'),
    Exercise(id: 'ex_plank', name: '平板支撑', bodyPart: '核心', category: '核心'),
    Exercise(id: 'ex_crunch', name: '卷腹', bodyPart: '核心', category: '核心'),
    Exercise(id: 'ex_treadmill', name: '跑步机', bodyPart: '有氧', category: '有氧'),
    Exercise(id: 'ex_cycling', name: '动感单车', bodyPart: '有氧', category: '有氧'),
  ];

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
