import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/progression_rule.dart';
import '../../data/models/training_program.dart';
import '../../data/models/workout_log.dart';
import '../../data/models/food.dart';
import '../../data/models/diet_log.dart';
import '../../data/models/user_profile.dart';
import 'sync_row_codec.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  String? get userId => _client.auth.currentUser?.id;

  Food _foodFromRow(Map<String, dynamic> r) => Food(
    id: r['id'] as String,
    name: r['name'] as String,
    caloriesPer100g: (r['calories_per_100g'] as num).toDouble(),
    proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
    carbsPer100g: (r['carbs_per_100g'] as num).toDouble(),
    fatPer100g: (r['fat_per_100g'] as num).toDouble(),
    source: r['source'] as String?,
  );

  Map<String, dynamic> _dietToRow(DietLog d, {String? ownerUserId}) => {
    'id': d.id,
    'user_id': ownerUserId ?? userId,
    'food_id': d.foodId,
    'date': d.date.toIso8601String().substring(0, 10),
    'meal_type': d.mealType.name,
    'grams': d.grams,
    'calories': d.calories,
  };

  DietLog _dietFromRow(Map<String, dynamic> r) => DietLog(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    foodId: r['food_id'] as String,
    date: DateTime.parse(r['date'] as String),
    mealType: MealType.values.firstWhere(
      (e) => e.name == r['meal_type'],
      orElse: () => MealType.lunch,
    ),
    grams: (r['grams'] as num).toDouble(),
    calories: (r['calories'] as num).toDouble(),
    createdAt: r['created_at'] != null
        ? DateTime.parse(r['created_at'] as String)
        : null,
  );

  UserProfile _profileFromRow(Map<String, dynamic> r) => UserProfile(
    id: r['id'] as String,
    email: r['email'] as String?,
    gender: Gender.values.firstWhere(
      (e) => e.name == r['gender'],
      orElse: () => Gender.male,
    ),
    age: r['age'] as int,
    heightCm: (r['height_cm'] as num).toDouble(),
    weightKg: (r['weight_kg'] as num).toDouble(),
    goal: FitnessGoal.values.firstWhere(
      (e) => e.name == r['goal'],
      orElse: () => FitnessGoal.maintain,
    ),
    bodyFatPct: r['body_fat_pct'] != null
        ? (r['body_fat_pct'] as num).toDouble()
        : null,
    displayName: r['display_name'] as String?,
  );

  // ---- Auth ----
  Future<void> signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(
    String email,
    String password,
    UserProfile profile,
  ) async {
    await _client.auth.signUp(email: email, password: password);
    await upsertProfile(profile);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ---- Profile ----
  Future<UserProfile?> getProfile() async {
    final uid = userId;
    if (uid == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return data == null ? null : _profileFromRow(data);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'gender': profile.gender.name,
      'age': profile.age,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'goal': profile.goal.name,
      'body_fat_pct': profile.bodyFatPct,
      'display_name': profile.displayName,
      'email': profile.email,
    });
  }

  // ---- Foods ----
  Future<List<Food>> searchFoods(String query) async {
    final response = await _client
        .from('foods')
        .select()
        .ilike('name', '%$query%')
        .limit(50);
    return (response as List).map((e) => _foodFromRow(e)).toList();
  }

  Future<List<Food>> getPublicFoods() async {
    final response = await _client
        .from('foods')
        .select()
        .filter('user_id', 'is', null)
        .order('name')
        .limit(100);
    return (response as List).map((e) => _foodFromRow(e)).toList();
  }

  // ---- Workout Logs ----
  Future<List<WorkoutLog>> getWorkoutLogs(DateTime date) async {
    final uid = userId;
    if (uid == null) return [];
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('user_id', uid)
        .eq('date', dateStr);
    return (response as List)
        .map(
          (row) => SyncRowCodec.workoutLogFromRow(
            Map<String, dynamic>.from(row as Map),
            currentUserId: uid,
          ),
        )
        .toList();
  }

  Future<List<WorkoutLog>> getWorkoutLogsForMonth(DateTime month) async {
    final uid = userId;
    if (uid == null) return [];
    final prefix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final start = '$prefix-01';
    final end = '$prefix-31';
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('user_id', uid)
        .gte('date', start)
        .lte('date', end);
    return (response as List)
        .map(
          (row) => SyncRowCodec.workoutLogFromRow(
            Map<String, dynamic>.from(row as Map),
            currentUserId: uid,
          ),
        )
        .toList();
  }

  Future<List<WorkoutLog>> getAllWorkoutLogs({int pageSize = 500}) async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _getAllOwnedRows(
      'workout_logs',
      userId: uid,
      pageSize: pageSize,
    );
    return rows
        .map((row) => SyncRowCodec.workoutLogFromRow(row, currentUserId: uid))
        .toList();
  }

  Future<void> addWorkoutLog(WorkoutLog log) async {
    final uid = _requireAuthenticatedUser();
    final row = SyncRowCodec.workoutLogToLegacyRow(log, currentUserId: uid);
    await _client.from('workout_logs').upsert(row);
  }

  Future<void> addWorkoutLogForSync(
    WorkoutLog log, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    final row = SyncRowCodec.workoutLogToLegacyRow(
      log,
      currentUserId: expectedUserId,
    );
    await _client.from('workout_logs').upsert(row);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  /// Requires `202607130001_training_sync_foundation.sql` to be deployed.
  /// Keep normal workout writes on [addWorkoutLog] until then.
  Future<void> upsertWorkoutLog(WorkoutLog log) async {
    final uid = _requireAuthenticatedUser();
    final row = SyncRowCodec.workoutLogToRow(log, currentUserId: uid);
    await _client.from('workout_logs').upsert(row);
  }

  Future<void> upsertWorkoutLogForSync(
    WorkoutLog log, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    final row = SyncRowCodec.workoutLogToRow(
      log,
      currentUserId: expectedUserId,
    );
    await _client.from('workout_logs').upsert(row);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<void> deleteWorkoutLog(String logId) async {
    final uid = _requireAuthenticatedUser();
    await _client
        .from('workout_logs')
        .delete()
        .eq('user_id', uid)
        .eq('id', logId);
  }

  Future<void> deleteWorkoutLogForSync(
    String logId, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    await _client
        .from('workout_logs')
        .delete()
        .eq('user_id', expectedUserId)
        .eq('id', logId);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  // ---- Training sync foundation ----
  // SyncService calls these only when FITFORGE_TRAINING_SYNC_V1 is enabled and
  // the matching migration has already been deployed.
  Future<List<TrainingProgram>> getAllTrainingPrograms({
    int pageSize = 500,
  }) async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _getAllOwnedRows(
      'training_programs',
      userId: uid,
      pageSize: pageSize,
    );
    return rows
        .map(
          (row) => SyncRowCodec.trainingProgramFromRow(row, currentUserId: uid),
        )
        .toList();
  }

  Future<void> upsertTrainingProgram(TrainingProgram program) async {
    final uid = _requireAuthenticatedUser();
    final row = SyncRowCodec.trainingProgramToRow(program, currentUserId: uid);
    await _client
        .from('training_programs')
        .upsert(row, onConflict: 'user_id,id');
  }

  Future<void> upsertTrainingProgramForSync(
    TrainingProgram program, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    final row = SyncRowCodec.trainingProgramToRow(
      program,
      currentUserId: expectedUserId,
    );
    await _client
        .from('training_programs')
        .upsert(row, onConflict: 'user_id,id');
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<void> deleteTrainingProgram(String programId) async {
    final uid = _requireAuthenticatedUser();
    await _client
        .from('training_programs')
        .delete()
        .eq('user_id', uid)
        .eq('id', programId);
  }

  Future<void> deleteTrainingProgramForSync(
    String programId, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    await _client
        .from('training_programs')
        .delete()
        .eq('user_id', expectedUserId)
        .eq('id', programId);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<List<ProgressionRule>> getAllProgressionRules({
    int pageSize = 500,
  }) async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _getAllOwnedRows(
      'progression_rules',
      userId: uid,
      pageSize: pageSize,
    );
    return rows
        .map(
          (row) => SyncRowCodec.progressionRuleFromRow(row, currentUserId: uid),
        )
        .toList();
  }

  Future<void> upsertProgressionRule(ProgressionRule rule) async {
    final uid = _requireAuthenticatedUser();
    final row = SyncRowCodec.progressionRuleToRow(rule, currentUserId: uid);
    await _client
        .from('progression_rules')
        .upsert(row, onConflict: 'user_id,id');
  }

  Future<void> upsertProgressionRuleForSync(
    ProgressionRule rule, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    final row = SyncRowCodec.progressionRuleToRow(
      rule,
      currentUserId: expectedUserId,
    );
    await _client
        .from('progression_rules')
        .upsert(row, onConflict: 'user_id,id');
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<void> deleteProgressionRule(String ruleId) async {
    final uid = _requireAuthenticatedUser();
    await _client
        .from('progression_rules')
        .delete()
        .eq('user_id', uid)
        .eq('id', ruleId);
  }

  Future<void> deleteProgressionRuleForSync(
    String ruleId, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    await _client
        .from('progression_rules')
        .delete()
        .eq('user_id', expectedUserId)
        .eq('id', ruleId);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<List<WorkoutSetLog>> getAllWorkoutSetLogs({int pageSize = 500}) async {
    final uid = userId;
    if (uid == null) return [];
    final rows = await _getAllOwnedRows(
      'workout_set_logs',
      userId: uid,
      pageSize: pageSize,
    );
    return rows
        .map(
          (row) => SyncRowCodec.workoutSetLogFromRow(row, currentUserId: uid),
        )
        .toList();
  }

  Future<void> upsertWorkoutSetLog(WorkoutSetLog log) async {
    final uid = _requireAuthenticatedUser();
    final row = SyncRowCodec.workoutSetLogToRow(log, currentUserId: uid);
    await _client
        .from('workout_set_logs')
        .upsert(row, onConflict: 'user_id,id');
  }

  Future<void> upsertWorkoutSetLogForSync(
    WorkoutSetLog log, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    final row = SyncRowCodec.workoutSetLogToRow(
      log,
      currentUserId: expectedUserId,
    );
    await _client
        .from('workout_set_logs')
        .upsert(row, onConflict: 'user_id,id');
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<void> deleteWorkoutSetLog(String setLogId) async {
    final uid = _requireAuthenticatedUser();
    await _client
        .from('workout_set_logs')
        .delete()
        .eq('user_id', uid)
        .eq('id', setLogId);
  }

  Future<void> deleteWorkoutSetLogForSync(
    String setLogId, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    await _client
        .from('workout_set_logs')
        .delete()
        .eq('user_id', expectedUserId)
        .eq('id', setLogId);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  // ---- Diet Logs ----
  Future<List<DietLog>> getDietLogs(DateTime date) async {
    final uid = userId;
    if (uid == null) return [];
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _client
        .from('diet_logs')
        .select()
        .eq('user_id', uid)
        .eq('date', dateStr);
    return (response as List).map((e) => _dietFromRow(e)).toList();
  }

  Future<void> addDietLog(DietLog log) async {
    await _client.from('diet_logs').upsert(_dietToRow(log));
  }

  Future<void> addDietLogForSync(
    DietLog log, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    if (log.userId != expectedUserId) {
      throw StateError('Diet log belongs to a different sync user.');
    }
    await _client
        .from('diet_logs')
        .upsert(_dietToRow(log, ownerUserId: expectedUserId));
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  Future<void> deleteDietLog(String logId) async {
    await _client.from('diet_logs').delete().eq('id', logId);
  }

  Future<void> deleteDietLogForSync(
    String logId, {
    required String expectedUserId,
  }) async {
    _requireExpectedAuthenticatedUser(expectedUserId);
    await _client
        .from('diet_logs')
        .delete()
        .eq('user_id', expectedUserId)
        .eq('id', logId);
    _requireExpectedAuthenticatedUser(expectedUserId);
  }

  // ---- Subscription ----
  Future<bool> getSubscriptionStatus() async {
    final uid = userId;
    if (uid == null) return false;
    final response = await _client
        .from('subscriptions')
        .select('tier')
        .eq('user_id', uid)
        .single();
    final tier = response['tier'] as String;
    return tier == 'pro_monthly' || tier == 'pro_yearly';
  }

  String _requireAuthenticatedUser() {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('A signed-in user is required for this write.');
    }
    return uid;
  }

  void _requireExpectedAuthenticatedUser(String expectedUserId) {
    final uid = _requireAuthenticatedUser();
    if (uid != expectedUserId) {
      throw StateError(
        'Authenticated user changed during sync: expected $expectedUserId, '
        'found $uid.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _getAllOwnedRows(
    String table, {
    required String userId,
    required int pageSize,
  }) async {
    if (pageSize <= 0 || pageSize > 1000) {
      throw RangeError.range(pageSize, 1, 1000, 'pageSize');
    }

    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await _client
          .from(table)
          .select()
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + pageSize - 1);
      final page = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      rows.addAll(page);
      if (page.length < pageSize) break;
      offset += page.length;
    }
    return rows;
  }
}
