import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/exercise.dart';
import '../models/workout_log.dart';
import '../models/food.dart';
import '../models/diet_log.dart';
import '../models/user_profile.dart';
import '../models/workout_template.dart';
import '../models/body_measurement.dart';
import '../models/progression_rule.dart';
import '../models/training_program.dart';
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

  Future<List<WorkoutLog>> getWorkoutLogs(String userId, DateTime date) async {
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
    final logs = data != null
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
    final logs = (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList();
    logs.removeWhere((l) => l.id == logId);
    await _storage.write(
      key: _key(userId, 'workout_logs'),
      value: jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WorkoutLog>> _getAllWorkoutLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutLog?> getLastWorkoutLogForExercise(
    String userId,
    String exerciseId,
    DateTime beforeDate,
  ) async {
    final logs = await _getAllWorkoutLogs(userId);
    final matches =
        logs
            .where(
              (l) => l.exerciseId == exerciseId && l.date.isBefore(beforeDate),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return matches.isNotEmpty ? matches.first : null;
  }

  // ---- Progression Rules ----
  Future<List<ProgressionRule>> getProgressionRules(String userId) async {
    final data = await _storage.read(key: _key(userId, 'progression_rules'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => ProgressionRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProgressionRule?> getProgressionRule(
    String userId,
    String exerciseId,
  ) async {
    final rules = await getProgressionRules(userId);
    for (final rule in rules) {
      if (rule.exerciseId == exerciseId) return rule;
    }
    return null;
  }

  Future<void> saveProgressionRule(String userId, ProgressionRule rule) async {
    final rules = await getProgressionRules(userId);
    final idx = rules.indexWhere((r) => r.exerciseId == rule.exerciseId);
    if (idx >= 0) {
      rules[idx] = rule;
    } else {
      rules.add(rule);
    }
    await _storage.write(
      key: _key(userId, 'progression_rules'),
      value: jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> deleteProgressionRule(String userId, String exerciseId) async {
    final rules = await getProgressionRules(userId);
    rules.removeWhere((r) => r.exerciseId == exerciseId);
    await _storage.write(
      key: _key(userId, 'progression_rules'),
      value: jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
  }

  // ---- Training Programs ----

  Future<List<TrainingProgram>> getTrainingPrograms(String userId) async {
    final data = await _storage.read(key: _key(userId, 'training_programs'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => TrainingProgram.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<TrainingProgram> _normalizeActiveTrainingPrograms(
    List<TrainingProgram> programs,
  ) {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final withMetadata = programs
        .map((program) => _withActivationMetadata(program, now))
        .toList();

    TrainingProgram? currentProgram;
    DateTime? currentStart;
    TrainingProgram? futureProgram;
    DateTime? futureStart;

    for (final program in withMetadata) {
      if (!program.active) continue;
      final start = _dateOnly(program.activatedAt ?? program.updatedAt);
      if (start.isAfter(today)) {
        if (futureProgram == null ||
            program.updatedAt.isAfter(futureProgram.updatedAt) ||
            (program.updatedAt == futureProgram.updatedAt &&
                start.isAfter(futureStart!))) {
          futureProgram = program;
          futureStart = start;
        }
        continue;
      }

      if (currentProgram == null ||
          start.isAfter(currentStart!) ||
          (start == currentStart &&
              program.updatedAt.isAfter(currentProgram.updatedAt))) {
        currentProgram = program;
        currentStart = start;
      }
    }

    return withMetadata.map((program) {
      if (!program.active) return program;
      final keep =
          program.id == currentProgram?.id || program.id == futureProgram?.id;
      return keep ? program : program.copyWith(active: false);
    }).toList();
  }

  TrainingProgram _withActivationMetadata(
    TrainingProgram program,
    DateTime activatedAt,
  ) {
    if (!program.active || program.activatedAt != null) return program;
    return program.copyWith(
      activatedAt: activatedAt,
      activatedDayIndex: program.normalizedCurrentDayIndex,
    );
  }

  Future<void> saveTrainingPrograms(
    String userId,
    List<TrainingProgram> programs,
  ) async {
    final normalized = _normalizeActiveTrainingPrograms(programs);
    await _storage.write(
      key: _key(userId, 'training_programs'),
      value: jsonEncode(normalized.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> saveTrainingProgram(
    String userId,
    TrainingProgram program,
  ) async {
    final programs = await getTrainingPrograms(userId);
    final idx = programs.indexWhere((p) => p.id == program.id);
    if (idx >= 0) {
      programs[idx] = program;
    } else {
      programs.add(program);
    }
    final now = DateTime.now();
    final normalized = program.active
        ? _normalizeActiveTrainingPrograms(
            programs
                .map(
                  (p) => p.id == program.id
                      ? _withActivationMetadata(p.copyWith(active: true), now)
                      : p,
                )
                .toList(),
          )
        : _normalizeActiveTrainingPrograms(programs);
    await saveTrainingPrograms(userId, normalized);
  }

  Future<void> deleteTrainingProgram(String userId, String programId) async {
    final programs = await getTrainingPrograms(userId);
    programs.removeWhere((p) => p.id == programId);
    await _storage.write(
      key: _key(userId, 'training_programs'),
      value: jsonEncode(programs.map((p) => p.toJson()).toList()),
    );
  }

  Future<TrainingProgram?> getActiveTrainingProgram(String userId) async {
    final programs = await getTrainingPrograms(userId);
    return activeTrainingProgramForUser(programs, userId);
  }

  Future<void> setActiveTrainingProgram(
    String userId,
    String programId, {
    DateTime? activatedAt,
    required int? plannedCycleCount,
  }) async {
    final programs = await getTrainingPrograms(userId);
    if (!programs.any((p) => p.id == programId)) return;
    final now = DateTime.now();
    final start = activatedAt ?? now;
    final futureActivation = _dateOnly(start).isAfter(_dateOnly(now));
    for (int i = 0; i < programs.length; i++) {
      final program = programs[i];
      final activating = program.id == programId;
      final shouldDeactivate =
          !activating &&
          program.active &&
          (!futureActivation ||
              _dateOnly(
                program.activatedAt ?? program.updatedAt,
              ).isAfter(_dateOnly(now)));
      final updated = program.copyWith(
        active: activating
            ? true
            : shouldDeactivate
            ? false
            : program.active,
        activatedAt: activating ? start : program.activatedAt,
        activatedDayIndex: activating
            ? program.normalizedCurrentDayIndex
            : program.activatedDayIndex,
        plannedCycleCount: activating
            ? plannedCycleCount
            : program.plannedCycleCount,
        clearPlannedCycleCount: activating && plannedCycleCount == null,
        pausePeriods: activating ? const [] : program.pausePeriods,
        updatedAt: activating ? now : program.updatedAt,
      );
      programs[i] = activating
          ? _withActivationMetadata(updated, now)
          : updated;
    }
    await saveTrainingPrograms(userId, programs);
  }

  Future<void> endTrainingProgram(String userId, String programId) async {
    final programs = await getTrainingPrograms(userId);
    final idx = programs.indexWhere((p) => p.id == programId);
    if (idx < 0) return;
    final program = programs[idx];
    if (!program.active && program.pausePeriods.isEmpty) return;
    programs[idx] = program.endExecution();
    await saveTrainingPrograms(userId, programs);
  }

  Future<void> saveWorkoutSetLogs(
    String userId,
    List<WorkoutSetLog> logs,
  ) async {
    final data = await _storage.read(key: _key(userId, 'workout_set_logs'));
    final existing = data != null
        ? (jsonDecode(data) as List)
              .map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
              .toList()
        : <WorkoutSetLog>[];
    final existingIds = existing.map((l) => l.id).toSet();
    for (final log in logs) {
      final idx = existing.indexWhere((item) => item.id == log.id);
      if (idx >= 0) {
        existing[idx] = log;
      } else if (!existingIds.contains(log.id)) {
        existing.add(log);
      }
    }
    await _storage.write(
      key: _key(userId, 'workout_set_logs'),
      value: jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<WorkoutSetLog>> getWorkoutSetLogs(
    String userId,
    String workoutLogId,
  ) async {
    final data = await _storage.read(key: _key(userId, 'workout_set_logs'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
        .where((log) => log.workoutLogId == workoutLogId)
        .toList();
  }

  Future<WorkoutLog?> getLastWorkoutLogForProgramExercise(
    String userId, {
    required String programId,
    required String programExerciseId,
    required DateTime beforeDate,
  }) async {
    final setLogData = await _storage.read(
      key: _key(userId, 'workout_set_logs'),
    );
    if (setLogData == null) return null;

    final setLogs = (jsonDecode(setLogData) as List)
        .map((e) => WorkoutSetLog.fromJson(e as Map<String, dynamic>))
        .where(
          (log) =>
              log.programId == programId &&
              log.programExerciseId == programExerciseId,
        )
        .toList();
    if (setLogs.isEmpty) return null;

    final workoutLogIds = setLogs.map((log) => log.workoutLogId).toSet();
    final logs =
        (await _getAllWorkoutLogs(userId))
            .where(
              (log) =>
                  workoutLogIds.contains(log.id) &&
                  log.date.isBefore(beforeDate),
            )
            .toList()
          ..sort((a, b) {
            final dateCompare = b.date.compareTo(a.date);
            if (dateCompare != 0) return dateCompare;
            final aCreated =
                a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bCreated =
                b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bCreated.compareTo(aCreated);
          });
    return logs.isNotEmpty ? logs.first : null;
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
    final logs = data != null
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
    final logs = (jsonDecode(data) as List)
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
    await _storage.write(key: _key(userId, 'is_pro'), value: isPro.toString());
  }

  // ---- Sync ----

  Future<void> saveWorkoutLogs(String userId, List<WorkoutLog> logs) async {
    final data = await _storage.read(key: _key(userId, 'workout_logs'));
    final existing = data != null
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
    final existing = data != null
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

  Future<void> removeUnsyncedWorkoutLogs(String userId, Set<String> ids) async {
    if (ids.isEmpty) return;
    final unsynced = await getUnsyncedWorkoutLogs(userId);
    unsynced.removeWhere((log) => ids.contains(log.id));
    await _storage.write(
      key: _key(userId, 'unsynced_workouts'),
      value: jsonEncode(unsynced.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<DietLog>> getUnsyncedDietLogs(String userId) async {
    final data = await _storage.read(key: _key(userId, 'unsynced_diets'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => DietLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addUnsyncedDiet(String userId, DietLog log) async {
    final unsynced = await getUnsyncedDietLogs(userId);
    final idx = unsynced.indexWhere((item) => item.id == log.id);
    if (idx >= 0) {
      unsynced[idx] = log;
    } else {
      unsynced.add(log);
    }
    await _storage.write(
      key: _key(userId, 'unsynced_diets'),
      value: jsonEncode(unsynced.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> removeUnsyncedDietLogs(String userId, Set<String> ids) async {
    if (ids.isEmpty) return;
    final unsynced = await getUnsyncedDietLogs(userId);
    unsynced.removeWhere((log) => ids.contains(log.id));
    await _storage.write(
      key: _key(userId, 'unsynced_diets'),
      value: jsonEncode(unsynced.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<String>> getPendingWorkoutDeletes(String userId) =>
      _getStringList(userId, 'pending_workout_deletes');

  Future<void> addPendingWorkoutDelete(String userId, String id) =>
      _addString(userId, 'pending_workout_deletes', id);

  Future<void> removePendingWorkoutDeletes(String userId, Set<String> ids) =>
      _removeStrings(userId, 'pending_workout_deletes', ids);

  Future<List<String>> getPendingDietDeletes(String userId) =>
      _getStringList(userId, 'pending_diet_deletes');

  Future<void> addPendingDietDelete(String userId, String id) =>
      _addString(userId, 'pending_diet_deletes', id);

  Future<void> removePendingDietDeletes(String userId, Set<String> ids) =>
      _removeStrings(userId, 'pending_diet_deletes', ids);

  Future<String?> getLastSyncTime(String userId) async {
    return _storage.read(key: _key(userId, 'last_sync'));
  }

  Future<void> setLastSyncTime(String userId) async {
    await _storage.write(
      key: _key(userId, 'last_sync'),
      value: DateTime.now().toIso8601String(),
    );
  }

  // ---- Templates ----
  Future<List<WorkoutTemplate>> getTemplates(String userId) async {
    final data = await _storage.read(key: _key(userId, 'templates'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => WorkoutTemplate.fromJson(e))
        .toList();
  }

  Future<void> saveTemplate(String userId, WorkoutTemplate template) async {
    final templates = await getTemplates(userId);
    templates.add(template);
    await _storage.write(
      key: _key(userId, 'templates'),
      value: jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> deleteTemplate(String userId, String templateId) async {
    final templates = await getTemplates(userId);
    templates.removeWhere((t) => t.id == templateId);
    await _storage.write(
      key: _key(userId, 'templates'),
      value: jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  // ---- Meal Templates ----
  Future<List<String>> getMealTemplates(String userId) async {
    final data = await _storage.read(key: _key(userId, 'meal_templates'));
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e['name'] as String).toList();
  }

  Future<void> saveMealTemplate(String userId, String name, String data) async {
    final templates = await _storage.read(key: _key(userId, 'meal_templates'));
    final list = templates != null ? (jsonDecode(templates) as List) : [];
    list.add({'name': name, 'data': data});
    await _storage.write(
      key: _key(userId, 'meal_templates'),
      value: jsonEncode(list),
    );
  }

  Future<String?> getMealTemplateData(String userId, String name) async {
    final data = await _storage.read(key: _key(userId, 'meal_templates'));
    if (data == null) return null;
    final list = jsonDecode(data) as List;
    for (final item in list) {
      if (item['name'] == name) return item['data'] as String;
    }
    return null;
  }

  // ---- Nutrition Plan ----
  Future<Map<String, dynamic>?> getNutritionPlan(String userId) async {
    final data = await _storage.read(key: _key(userId, 'nutrition_plan'));
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    if (decoded.isEmpty) return null;
    return decoded;
  }

  Future<void> saveNutritionPlan(
    String userId,
    Map<String, dynamic> plan,
  ) async {
    await _storage.write(
      key: _key(userId, 'nutrition_plan'),
      value: jsonEncode(plan),
    );
  }

  Future<void> deleteNutritionPlan(String userId) async {
    await _storage.delete(key: _key(userId, 'nutrition_plan'));
  }

  // ---- Body Measurements ----
  Future<List<BodyMeasurement>> getBodyMeasurements(String userId) async {
    final data = await _storage.read(key: _key(userId, 'body_measurements'));
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((e) => BodyMeasurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveBodyMeasurement(String userId, BodyMeasurement entry) async {
    final entries = await getBodyMeasurements(userId);
    entries.insert(0, entry);
    await _storage.write(
      key: _key(userId, 'body_measurements'),
      value: jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteBodyMeasurement(String userId, String id) async {
    final entries = await getBodyMeasurements(userId);
    entries.removeWhere((e) => e.id == id);
    await _storage.write(
      key: _key(userId, 'body_measurements'),
      value: jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  Future<List<String>> _getStringList(String userId, String type) async {
    final data = await _storage.read(key: _key(userId, type));
    if (data == null) return [];
    return (jsonDecode(data) as List).map((e) => e.toString()).toList();
  }

  Future<void> _saveStringList(
    String userId,
    String type,
    List<String> values,
  ) async {
    await _storage.write(key: _key(userId, type), value: jsonEncode(values));
  }

  Future<void> _addString(String userId, String type, String value) async {
    final values = await _getStringList(userId, type);
    if (!values.contains(value)) values.add(value);
    await _saveStringList(userId, type, values);
  }

  Future<void> _removeStrings(
    String userId,
    String type,
    Set<String> valuesToRemove,
  ) async {
    if (valuesToRemove.isEmpty) return;
    final values = await _getStringList(userId, type);
    values.removeWhere(valuesToRemove.contains);
    await _saveStringList(userId, type, values);
  }

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
